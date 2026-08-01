import SwiftUI
import Observation
import AVFoundation

enum LibraryView: Hashable {
    case library
    case playlist(String)
}

enum RepeatMode: String, Codable {
    case off, all, one
}

enum LibrarySortField: String, CaseIterable, Identifiable {
    case title
    case artist
    case album
    case dateAdded

    var id: Self { self }

    var title: String {
        switch self {
        case .title: return "标题"
        case .artist: return "艺术家"
        case .album: return "专辑"
        case .dateAdded: return "添加时间"
        }
    }
}

enum LibrarySortDirection {
    case ascending
    case descending

    var title: String {
        switch self {
        case .ascending: return "升序"
        case .descending: return "降序"
        }
    }

    var systemImage: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

enum GroupNameValidation {
    static let maxLength = 24
}

enum ImportPhase: Equatable, Sendable {
    case idle
    case processing(completed: Int, total: Int)

    var isImporting: Bool {
        if case .processing = self { return true }
        return false
    }

    var completed: Int {
        if case .processing(let completed, _) = self { return completed }
        return 0
    }

    var total: Int {
        if case .processing(_, let total) = self { return total }
        return 0
    }

    var message: String? {
        guard case .processing(let completed, let total) = self else { return nil }
        return "正在导入 \(completed)/\(total)"
    }
}

enum LibraryActivityKind: Equatable, Sendable {
    case importing
    case scanning

    var progressTitle: String {
        switch self {
        case .importing: return "正在导入"
        case .scanning: return "正在扫描"
        }
    }

    var cancellationMessage: String {
        switch self {
        case .importing: return "已取消音乐导入"
        case .scanning: return "已取消音乐文件夹扫描"
        }
    }
}

struct LyricsPageState: Equatable {
    var songId: String
    var lyricsURL: URL
    var lyrics: ParsedLyrics
}

struct PendingSongRemoval: Identifiable {
    enum Scope {
        case library
        case playlist(id: String, name: String)
    }

    let id = UUID()
    var songIds: [String]
    var scope: Scope
}

@MainActor
@Observable
final class AppState {
    static let favoritesGroupId = "system-favorites"
    static let favoritesGroupName = "我的收藏"
    static var storeDirectoryOverride: URL?
    static var stripsBundledSampleDataOverride: Bool?

    nonisolated private static let persistenceQueue = DispatchQueue(label: "com.crate.library-persistence", qos: .utility)
    nonisolated private static let maxArtworkDataSize = 512 * 1024
    nonisolated private static let maxArtworkPixelLength = 640

    private struct ImportAlbumKey: Hashable, Sendable {
        var title: String
        var artist: String
    }

    struct AlbumArtworkUpdate: Sendable {
        var albumId: String
        var artworkData: Data
        var replacesExisting = false
    }

    struct ImportResult: Sendable {
        var songs: [Song] = []
        var newAlbums: [Album] = []
        var albumArtworkUpdates: [AlbumArtworkUpdate] = []
        var skippedExisting = 0
        var skippedBroken = 0
    }

    private struct ParsedMetadata: Sendable {
        var title: String
        var artist: String?
        var albumName: String?
        var duration: Double
        var embeddedArtworkData: Data?
        var sidecarArtworkData: Data?
    }

    private struct FolderScanResult: Sendable {
        var songs: [Song] = []
        var newAlbums: [Album] = []
        var albumArtworkUpdates: [AlbumArtworkUpdate] = []
        var successfulSources: [MusicFolderSource] = []
        var failedSourceNames: [String] = []
        var skippedBroken = 0
        var addedCount = 0
        var movedCount = 0
        var refreshedCount = 0
    }

    struct FilenameMetadata: Equatable, Sendable {
        var title: String
        var artist: String?
    }

    private struct BackfilledArtwork: Sendable {
        var songId: String
        var path: String
        var artworkData: Data
    }

    private struct RelocationUpdate: Sendable {
        var songId: String
        var oldPath: String
        var newURL: URL
    }

    // ── 主题（持久化键与设计稿 localStorage 对齐） ──
    var theme: AppTheme {
        didSet {
            if persistenceEnabled {
                UserDefaults.standard.set(theme.rawValue, forKey: "lmp-theme")
            }
        }
    }
    var tokens: ThemeTokens { ThemeTokens.of(theme) }

    // ── 数据（变更后持久化到 Application Support，design.md D6） ──
    var albums: [Album] {
        didSet {
            albumsById = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
            persist()
        }
    }
    var library: [Song] {
        didSet {
            songsById = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })
            persist()
        }
    }
    var playlists: [Playlist] { didSet { persist() } }
    var musicFolders: [MusicFolderSource] { didSet { persist() } }

    // 索引缓存：随数据变更重建，避免每次渲染/查询全量建字典
    private(set) var albumsById: [String: Album] = [:]
    private(set) var songsById: [String: Song] = [:]

    // ── 视图状态 ──
    var view: LibraryView = .library {
        didSet {
            guard view != oldValue else { return }
            clearSongSelection()
        }
    }
    var search = "" {
        didSet {
            guard search != oldValue else { return }
            setSongSelection(selectedSongIds)
        }
    }
    var selectedId: String?
    var selectedSongIds: Set<String> = []
    var librarySortField: LibrarySortField = .title
    var librarySortDirection: LibrarySortDirection = .ascending
    var pendingSongRemoval: PendingSongRemoval?
    private(set) var queueOpen = false
    var toast: String?
    var dragOver = false
    var lyricsPage: LyricsPageState?
    var updatePhase: AppUpdatePhase = .idle
    var availableUpdate: AvailableAppUpdate?
    var updateDialogPresented = false
    private(set) var importPhase: ImportPhase = .idle
    private(set) var libraryActivityKind: LibraryActivityKind = .importing

    var libraryActivityMessage: String? {
        guard case .processing(let completed, let total) = importPhase else { return nil }
        return "\(libraryActivityKind.progressTitle) \(completed)/\(total)"
    }

    // ── 失效曲目（运行时派生，不持久化；design.md D1） ──
    var missingIds: Set<String> = []

    // ── 播放 ──
    let player = PlayerStore()

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var importTask: Task<Void, Never>?
    @ObservationIgnored private var importWorkerTask: Task<ImportResult, Never>?
    @ObservationIgnored private var folderScanWorkerTask: Task<FolderScanResult, Never>?
    @ObservationIgnored private var loaded = false
    @ObservationIgnored nonisolated private let persistenceLock = NSLock()
    @ObservationIgnored nonisolated(unsafe) private var pendingPersistenceSnapshot: PersistedLibrary?
    @ObservationIgnored nonisolated(unsafe) private var persistenceGeneration = 0
    @ObservationIgnored nonisolated(unsafe) private var persistenceDrainScheduled = false
    @ObservationIgnored private var persistenceFailureReported = false
    @ObservationIgnored private var persistenceProtectionActive = false
    @ObservationIgnored private let persistenceEnabled: Bool
    @ObservationIgnored nonisolated private let persistenceStoreURL: URL

    init(screenshotScene: ScreenshotScene? = nil) {
        persistenceEnabled = screenshotScene == nil
        let savedTheme = UserDefaults.standard.string(forKey: "lmp-theme")
        theme = screenshotScene?.theme ?? AppTheme(rawValue: savedTheme ?? "") ?? .light

        let storeURL = Self.storeURL
        persistenceStoreURL = storeURL
        let hasPersistedLibrary = FileManager.default.fileExists(atPath: storeURL.path)
        var loadFailed = false
        if screenshotScene != nil {
            albums = ScreenshotFixture.albums
            library = ScreenshotFixture.songs
            playlists = ScreenshotFixture.playlists
            musicFolders = []
        } else if hasPersistedLibrary {
            do {
                let data = try Data(contentsOf: storeURL)
                let persisted = try JSONDecoder().decode(PersistedLibrary.self, from: data)
                let sanitized = Self.sanitizedPersistedLibrary(persisted)
                albums = sanitized.albums
                library = Self.songsWithFilenameMetadataFallback(sanitized.songs)
                playlists = Self.normalizedSystemGroups(sanitized.playlists)
                musicFolders = sanitized.musicFolders
            } catch {
                loadFailed = true
                persistenceProtectionActive = true
                albums = []
                library = []
                playlists = Self.normalizedSystemGroups([])
                musicFolders = []
            }
        } else {
            albums = []
            library = []
            playlists = Self.normalizedSystemGroups([])
            musicFolders = []
        }
        loaded = true
        // init 中赋值不触发 didSet，手动建一次索引
        albumsById = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        songsById = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })
        if screenshotScene != nil {
            // 截图 fixture 仅存在于当前进程，不落盘。
        } else if loadFailed {
            showToast("曲库读取失败，已暂时以空资料库启动")
        } else {
            persist()
        }
        if screenshotScene == nil {
            backfillSidecarArtwork()
        }

        player.songProvider = { [weak self] id in self?.songsById[id] }
        player.onToast = { [weak self] msg in self?.showToast(msg) }
        player.onMissing = { [weak self] id in self?.markMissing(id) }
        if let screenshotScene {
            ScreenshotFixture.configurePlayback(in: self, for: screenshotScene)
        } else {
            player.configurePlaybackMemory(url: Self.playbackMemoryURL)
            player.restorePlaybackMemory(availableSongs: songsById)
        }

        // 启动后台批量探测失效曲目（design.md D2）
        if screenshotScene == nil {
            probeAvailability()
            if !musicFolders.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.scanMusicFolders(reportCompletion: false)
                }
            }
        }
    }

    func flushPersistence() {
        guard loaded, persistenceEnabled else { return }
        player.flushPlaybackMemory()
        guard !persistenceProtectionActive else { return }
        let snapshot = currentPersistenceSnapshot
        persistenceLock.lock()
        pendingPersistenceSnapshot = snapshot
        persistenceGeneration &+= 1
        persistenceLock.unlock()

        Self.persistenceQueue.sync { [weak self] in
            do {
                guard let self else { return }
                try Self.writePersistenceSnapshot(snapshot, to: self.persistenceStoreURL)
                self.markPersistenceWriteSucceeded()
            } catch {
                self?.reportPersistenceWriteFailure(error)
            }
            guard let self else { return }
            self.persistenceLock.lock()
            self.pendingPersistenceSnapshot = snapshot
            self.persistenceDrainScheduled = false
            self.persistenceLock.unlock()
        }
    }

    // ── 失效曲目探测/标记（spec: track-availability，design.md D1/D2） ──

    /// 后台遍历曲库，标记文件已不存在的导入曲目；拔/插盘后重启重扫即自洽
    func probeAvailability() {
        let snapshot = Dictionary(uniqueKeysWithValues: library.compactMap { song in
            song.fileURL.map { (song.id, $0.path) }
        })
        Task.detached(priority: .utility) { [weak self, snapshot] in
            var missing: Set<String> = []
            for (id, path) in snapshot where !FileManager.default.fileExists(atPath: path) {
                missing.insert(id)
            }
            await self?.applyMissing(missing, for: snapshot)
        }
    }

    @MainActor private func applyMissing(_ ids: Set<String>, for snapshot: [String: String]) {
        let currentPaths = Dictionary(uniqueKeysWithValues: library.compactMap { song in
            song.fileURL.map { (song.id, $0.path) }
        })
        let currentIds = Set(currentPaths.keys)
        let stillMissing = ids.filter { id in
            currentPaths[id] == snapshot[id]
        }
        missingIds = missingIds.intersection(currentIds).union(stillMissing)
    }

    func markMissing(_ id: String) { missingIds.insert(id) }
    func clearMissing(_ id: String) { missingIds.remove(id) }

    // ── 当前视图歌曲（显示列表含搜索过滤，播放上下文不含搜索过滤） ──
    var viewPlaylist: Playlist? {
        if case .playlist(let id) = view { return playlists.first { $0.id == id } }
        return nil
    }

    var viewTitle: String {
        switch view {
        case .library: return "歌曲"
        case .playlist: return viewPlaylist?.name ?? ""
        }
    }

    var viewPlaybackSongs: [Song] {
        if let pl = viewPlaylist {
            let byId = songsById
            return pl.songIds.compactMap { byId[$0] }
        }
        return library
    }

    var viewSongs: [Song] {
        var list = viewPlaybackSongs
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter { s in
                let album = s.albumId.flatMap { albumsById[$0] }
                let artist = s.artist ?? album?.artist ?? ""
                return s.title.localizedStandardContains(q)
                    || artist.localizedStandardContains(q)
                    || (album?.title.localizedStandardContains(q) ?? false)
            }
        }
        return sortedSongs(list)
    }

    var selectedVisibleSongs: [Song] {
        viewSongs.filter { selectedSongIds.contains($0.id) }
    }

    func setSongSelection(_ ids: Set<String>) {
        let visibleIds = Set(viewSongs.map(\.id))
        let normalizedIds = ids.intersection(visibleIds)
        let primaryId = viewSongs.first(where: { normalizedIds.contains($0.id) })?.id
        if selectedSongIds != normalizedIds {
            selectedSongIds = normalizedIds
        }
        if selectedId != primaryId {
            selectedId = primaryId
        }
    }

    func selectOnly(_ songId: String) {
        setSongSelection([songId])
    }

    func clearSongSelection() {
        selectedSongIds.removeAll()
        selectedId = nil
    }

    func setLibrarySort(_ field: LibrarySortField) {
        if librarySortField == field {
            librarySortDirection = librarySortDirection == .ascending ? .descending : .ascending
        } else {
            librarySortField = field
            librarySortDirection = .ascending
        }
    }

    func toggleLibrarySortDirection() {
        librarySortDirection = librarySortDirection == .ascending ? .descending : .ascending
    }

    private func sortedSongs(_ songs: [Song]) -> [Song] {
        songs.enumerated().sorted { lhs, rhs in
            let comparison = compareForCurrentSort(lhs.element, rhs.element)
            if comparison == .orderedSame {
                return lhs.offset < rhs.offset
            }
            switch librarySortDirection {
            case .ascending: return comparison == .orderedAscending
            case .descending: return comparison == .orderedDescending
            }
        }.map(\.element)
    }

    private func compareForCurrentSort(_ lhs: Song, _ rhs: Song) -> ComparisonResult {
        switch librarySortField {
        case .title:
            return lhs.title.localizedStandardCompare(rhs.title)
        case .artist:
            return artistName(for: lhs).localizedStandardCompare(artistName(for: rhs))
        case .album:
            return albumTitle(for: lhs).localizedStandardCompare(albumTitle(for: rhs))
        case .dateAdded:
            switch (lhs.dateAdded, rhs.dateAdded) {
            case let (lhsDate?, rhsDate?):
                if lhsDate == rhsDate { return .orderedSame }
                return lhsDate < rhsDate ? .orderedAscending : .orderedDescending
            case (_?, nil):
                return librarySortDirection == .ascending ? .orderedAscending : .orderedDescending
            case (nil, _?):
                return librarySortDirection == .ascending ? .orderedDescending : .orderedAscending
            case (nil, nil):
                return .orderedSame
            }
        }
    }

    func artistName(for song: Song) -> String {
        song.artist ?? song.albumId.flatMap { albumsById[$0]?.artist } ?? "未知艺人"
    }

    func albumTitle(for song: Song) -> String {
        song.albumId.flatMap { albumsById[$0]?.title } ?? "未知专辑"
    }

    // ── 待播清单面板 ──

    func openQueue() {
        queueOpen = true
    }

    func closeQueue() {
        queueOpen = false
    }

    func toggleQueue() {
        queueOpen.toggle()
    }

    // ── 歌词（同名 .lrc sidecar） ──

    func openLyricsForCurrentSong() {
        guard let song = player.currentSong else {
            showToast("当前没有播放歌曲")
            return
        }
        guard let page = loadLyricsPage(for: song, reportFailure: true) else { return }
        closeQueue()
        lyricsPage = page
    }

    func closeLyricsPage() {
        closeQueue()
        lyricsPage = nil
    }

    func refreshLyricsPageForCurrentSong() {
        guard lyricsPage != nil else { return }
        guard let song = player.currentSong else {
            lyricsPage = nil
            return
        }
        guard let page = loadLyricsPage(for: song, reportFailure: true) else {
            lyricsPage = nil
            return
        }
        lyricsPage = page
    }

    private func lyricsURL(for song: Song) -> URL? {
        song.fileURL?.deletingPathExtension().appendingPathExtension("lrc")
    }

    private func loadLyricsPage(for song: Song, reportFailure: Bool) -> LyricsPageState? {
        guard let url = lyricsURL(for: song),
              FileManager.default.fileExists(atPath: url.path) else {
            if reportFailure { showToast("未找到同名歌词文件") }
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            guard let source = LRCFileReader.decode(data) else {
                if reportFailure { showToast("歌词文件无法解析") }
                return nil
            }
            let lyrics = try LRCParser.parse(source)
            return LyricsPageState(songId: song.id, lyricsURL: url, lyrics: lyrics)
        } catch {
            if reportFailure { showToast("歌词文件无法解析") }
            return nil
        }
    }

    // ── 系统分组 / 我的收藏 ──

    var favoritesGroup: Playlist? {
        playlists.first { Self.isFavoritesGroupId($0.id) }
    }

    func isSystemGroup(_ group: Playlist) -> Bool {
        Self.isFavoritesGroupId(group.id)
    }

    func isFavorite(_ song: Song) -> Bool {
        favoritesGroup?.songIds.contains(song.id) == true
    }

    func toggleFavorite(_ song: Song) {
        allowPersistenceAfterUserChange()
        if isFavorite(song) {
            updatePlaylists { groups in
                groups.map { group in
                    var group = group
                    if Self.isFavoritesGroupId(group.id) {
                        group.songIds.removeAll { $0 == song.id }
                    }
                    return group
                }
            }
            showToast("已从「\(Self.favoritesGroupName)」移除")
        } else {
            updatePlaylists { groups in
                groups.map { group in
                    var group = group
                    if Self.isFavoritesGroupId(group.id), !group.songIds.contains(song.id) {
                        group.songIds.append(song.id)
                    }
                    return group
                }
            }
            showToast("已收藏到「\(Self.favoritesGroupName)」")
        }
    }

    func setFavorite(_ favorite: Bool, songIds: [String]) {
        let validIds = orderedValidSongIds(songIds)
        guard !validIds.isEmpty else { return }
        let validIdSet = Set(validIds)
        allowPersistenceAfterUserChange()
        updatePlaylists { groups in
            groups.map { group in
                guard Self.isFavoritesGroupId(group.id) else { return group }
                var group = group
                if favorite {
                    let existing = Set(group.songIds)
                    group.songIds.append(contentsOf: validIds.filter { !existing.contains($0) })
                } else {
                    group.songIds.removeAll { validIdSet.contains($0) }
                }
                return group
            }
        }
        showToast(favorite
            ? "已收藏 \(validIds.count) 首歌曲"
            : "已取消收藏 \(validIds.count) 首歌曲")
    }

    // ── Toast ──
    func showToast(_ msg: String) {
        toastTask?.cancel()
        toast = msg
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2200))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    // ── 曲库操作（player-app.jsx handleMenuAction） ──

    private func normalizedGroupName(_ rawName: String) -> String {
        rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    func groupNameError(_ rawName: String, excluding groupId: String? = nil) -> String? {
        let name = normalizedGroupName(rawName)
        if name.isEmpty { return "请输入分组名称" }
        if name.count > GroupNameValidation.maxLength { return "分组名称不能超过 \(GroupNameValidation.maxLength) 个字符" }
        if playlists.contains(where: { $0.id != groupId && $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return "已存在同名分组"
        }

        var hasLetterOrNumber = false
        let allowedSymbols = Set("-_·&+#()（）")
        for ch in name {
            if ch.isLetter || ch.isNumber {
                hasLetterOrNumber = true
                continue
            }
            if ch == " " || allowedSymbols.contains(ch) { continue }
            return "名称只能包含中英文、数字、空格和常用连接符"
        }
        return hasLetterOrNumber ? nil : "名称不能全是符号"
    }

    @discardableResult
    func createGroup(named rawName: String) -> Playlist? {
        guard groupNameError(rawName) == nil else { return nil }
        allowPersistenceAfterUserChange()
        let name = normalizedGroupName(rawName)
        let group = Playlist(id: "grp-" + UUID().uuidString, name: name, songIds: [])
        updatePlaylists { $0 + [group] }
        view = .playlist(group.id)
        showToast("已创建分组「\(name)」")
        return group
    }

    func renameGroup(_ groupId: String, to rawName: String) -> Bool {
        guard !Self.isFavoritesGroupId(groupId) else { return false }
        guard groupNameError(rawName, excluding: groupId) == nil else { return false }
        allowPersistenceAfterUserChange()
        let name = normalizedGroupName(rawName)
        var renamed = false
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                if group.id == groupId {
                    group.name = name
                    renamed = true
                }
                return group
            }
        }
        if renamed { showToast("已重命名为「\(name)」") }
        return renamed
    }

    func deleteGroup(_ groupId: String) {
        guard !Self.isFavoritesGroupId(groupId) else { return }
        guard let group = playlists.first(where: { $0.id == groupId }) else { return }
        allowPersistenceAfterUserChange()
        updatePlaylists { groups in groups.filter { $0.id != groupId } }
        if case .playlist(let id) = view, id == groupId {
            view = .library
        }
        showToast("已删除分组「\(group.name)」")
    }

    func moveGroup(_ groupId: String, to destinationIndex: Int) {
        guard !Self.isFavoritesGroupId(groupId) else { return }
        guard let sourceIndex = playlists.firstIndex(where: { $0.id == groupId }) else { return }
        allowPersistenceAfterUserChange()
        var updated = playlists
        let moved = updated.remove(at: sourceIndex)
        let safeIndex = Swift.min(Swift.max(destinationIndex, 1), updated.count)
        updated.insert(moved, at: safeIndex)
        playlists = Self.normalizedSystemGroups(updated)
    }

    func addSong(_ song: Song, to playlist: Playlist) {
        guard let current = playlists.first(where: { $0.id == playlist.id }) else { return }
        if current.songIds.contains(song.id) {
            showToast("「\(song.title)」已在分组「\(current.name)」中")
            return
        }
        allowPersistenceAfterUserChange()
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                if group.id == current.id { group.songIds.append(song.id) }
                return group
            }
        }
        showToast("已添加到分组「\(current.name)」")
    }

    @discardableResult
    func addSongs(_ songIds: [String], toGroupId groupId: String) -> Int {
        guard let current = playlists.first(where: { $0.id == groupId }),
              !isSystemGroup(current) else { return 0 }
        let validIds = orderedValidSongIds(songIds)
        let existingIds = Set(current.songIds)
        let idsToAdd = validIds.filter { !existingIds.contains($0) }
        guard !idsToAdd.isEmpty else {
            showToast("所选歌曲已在分组「\(current.name)」中")
            return 0
        }
        allowPersistenceAfterUserChange()
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                if group.id == current.id {
                    group.songIds.append(contentsOf: idsToAdd)
                }
                return group
            }
        }
        showToast("已添加 \(idsToAdd.count) 首歌曲到「\(current.name)」")
        return idsToAdd.count
    }

    func addSongsToQueue(_ songIds: [String]) {
        let songs = orderedValidSongIds(songIds).compactMap { songsById[$0] }
        player.addToQueue(songs)
    }

    func removeSong(_ song: Song) {
        allowPersistenceAfterUserChange()
        removeSongRecords([song.id])
        showToast("已从资料库移除「\(song.title)」")
    }

    private func removeSongRecord(_ song: Song) {
        removeSongRecords([song.id])
    }

    func requestRemoval(of songIds: [String]) {
        let validIds = orderedValidSongIds(songIds)
        guard !validIds.isEmpty else { return }
        if validIds.count == 1, let song = songsById[validIds[0]] {
            if let playlist = viewPlaylist {
                removeSong(song, from: playlist)
            } else {
                removeSong(song)
            }
            return
        }
        if let playlist = viewPlaylist {
            pendingSongRemoval = PendingSongRemoval(
                songIds: validIds,
                scope: .playlist(id: playlist.id, name: playlist.name)
            )
        } else {
            pendingSongRemoval = PendingSongRemoval(songIds: validIds, scope: .library)
        }
    }

    func cancelPendingSongRemoval() {
        pendingSongRemoval = nil
    }

    func confirmPendingSongRemoval() {
        guard let pending = pendingSongRemoval else { return }
        pendingSongRemoval = nil
        switch pending.scope {
        case .library:
            removeSongsFromLibrary(pending.songIds)
        case .playlist(let id, _):
            removeSongs(pending.songIds, fromGroupId: id)
        }
    }

    func removeSongsFromLibrary(_ songIds: [String]) {
        let validIds = orderedValidSongIds(songIds)
        guard !validIds.isEmpty else { return }
        allowPersistenceAfterUserChange()
        removeSongRecords(validIds)
        showToast("已从资料库移除 \(validIds.count) 首歌曲")
    }

    private func removeSongRecords(_ songIds: [String]) {
        let ids = Set(songIds)
        guard !ids.isEmpty else { return }
        library.removeAll { ids.contains($0.id) }
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                group.songIds.removeAll { ids.contains($0) }
                return group
            }
        }
        for id in songIds {
            player.handleSongRemoved(id)
        }
        selectedSongIds.subtract(ids)
        if let selectedId, ids.contains(selectedId) {
            self.selectedId = selectedVisibleSongs.first?.id
        }
        missingIds.subtract(ids)
    }

    func deleteLocalFile(for song: Song) {
        guard let url = song.fileURL?.standardizedFileURL else {
            showToast("示例曲目没有对应文件")
            return
        }
        guard confirmDeleteLocalFile(songTitle: song.title, fileName: url.lastPathComponent) else { return }

        let fileExists = FileManager.default.fileExists(atPath: url.path)
        let sidecarURLs = existingDeletionSidecarURLs(for: url)
        if fileExists {
            do {
                try moveToTrash(url)
            } catch {
                showToast("删除文件失败：\(error.localizedDescription)")
                return
            }
        }
        let failedSidecars = moveSidecarsToTrash(sidecarURLs)

        allowPersistenceAfterUserChange()
        removeSongRecord(song)
        if !failedSidecars.isEmpty {
            let names = failedSidecars.map(\.lastPathComponent).joined(separator: "、")
            showToast("已移除「\(song.title)」，但未能删除：\(names)")
        } else if fileExists {
            let sidecarCount = sidecarURLs.count
            let suffix = sidecarCount > 0 ? "，并同步移除 \(sidecarCount) 个关联文件" : ""
            showToast("已将「\(song.title)」移到废纸篓并移除资料库记录\(suffix)")
        } else {
            showToast("本地文件已不存在，已移除「\(song.title)」的资料库记录")
        }
    }

    private func confirmDeleteLocalFile(songTitle: String, fileName: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "移到废纸篓并移除记录？"
        alert.informativeText = "这会将本地音频文件「\(fileName)」移到废纸篓，并同步移除同名 .jpg 专辑图片和 .lrc 歌词文件；同时会从 Crate 资料库中移除「\(songTitle)」。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        alert.buttons.first?.hasDestructiveAction = true
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func existingDeletionSidecarURLs(for audioURL: URL) -> [URL] {
        let baseURL = audioURL.deletingPathExtension()
        return ["jpg", "lrc"]
            .map { baseURL.appendingPathExtension($0).standardizedFileURL }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func moveSidecarsToTrash(_ urls: [URL]) -> [URL] {
        urls.filter { url in
            do {
                try moveToTrash(url)
                return false
            } catch {
                return true
            }
        }
    }

    private func moveToTrash(_ url: URL) throws {
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
    }

    func removeSong(_ song: Song, from playlist: Playlist) {
        guard playlists.contains(where: { $0.id == playlist.id && $0.songIds.contains(song.id) }) else { return }
        allowPersistenceAfterUserChange()
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                if group.id == playlist.id {
                    group.songIds.removeAll { $0 == song.id }
                }
                return group
            }
        }
        selectedSongIds.remove(song.id)
        if selectedId == song.id { selectedId = selectedVisibleSongs.first?.id }
        showToast("已从分组「\(playlist.name)」移除")
    }

    func removeSongs(_ songIds: [String], fromGroupId groupId: String) {
        guard let playlist = playlists.first(where: { $0.id == groupId }) else { return }
        let ids = Set(orderedValidSongIds(songIds))
        let removableIds = ids.intersection(playlist.songIds)
        guard !removableIds.isEmpty else { return }
        allowPersistenceAfterUserChange()
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                if group.id == groupId {
                    group.songIds.removeAll { removableIds.contains($0) }
                }
                return group
            }
        }
        selectedSongIds.subtract(removableIds)
        if let selectedId, removableIds.contains(selectedId) {
            self.selectedId = selectedVisibleSongs.first?.id
        }
        showToast("已从分组「\(playlist.name)」移除 \(removableIds.count) 首歌曲")
    }

    private func orderedValidSongIds(_ songIds: [String]) -> [String] {
        var seen = Set<String>()
        return songIds.filter { songsById[$0] != nil && seen.insert($0).inserted }
    }

    func clearLibrary() {
        let count = library.count
        guard count > 0 else { return }

        allowPersistenceAfterUserChange()
        player.resetPlaybackSession()
        albums = []
        library = []
        musicFolders = []
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                group.songIds = []
                return group
            }
        }
        missingIds.removeAll()
        view = .library
        clearSongSelection()
        search = ""
        showToast("已清空歌曲列表（\(count) 首）")
    }

    /// 为失效曲目重新定位文件，并自动批量修复同一旧目录下的其他失效曲目（spec: track-availability，design.md D6）
    func relocate(_ song: Song) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = AudioFileSupport.contentTypes
        panel.prompt = "重新定位"
        guard panel.runModal() == .OK, let newURL = panel.urls.first else { return }
        guard let oldURL = song.fileURL else { return }

        let oldDir = oldURL.deletingLastPathComponent().standardizedFileURL.path
        let newDir = newURL.deletingLastPathComponent()
        let oldPath = oldURL.standardizedFileURL.path
        let songId = song.id
        let songTitle = song.title
        let librarySnapshot = library
        let missingIdsSnapshot = missingIds

        Task.detached(priority: .userInitiated) { [weak self, librarySnapshot, missingIdsSnapshot] in
            guard Self.canDecodeAudio(at: newURL) else {
                await self?.showRelocationFailure()
                return
            }

            var updates = [
                RelocationUpdate(songId: songId, oldPath: oldPath, newURL: newURL)
            ]
            for s in librarySnapshot {
                // 仅修复同一旧目录、且新目录下存在同名文件的其他失效曲目
                guard s.id != songId,
                      missingIdsSnapshot.contains(s.id),
                      let sURL = s.fileURL,
                      sURL.deletingLastPathComponent().standardizedFileURL.path == oldDir else { continue }
                let candidate = newDir.appendingPathComponent(sURL.lastPathComponent)
                if Self.canDecodeAudio(at: candidate) {
                    updates.append(RelocationUpdate(
                        songId: s.id,
                        oldPath: sURL.standardizedFileURL.path,
                        newURL: candidate
                    ))
                }
            }

            await self?.applyRelocationUpdates(updates, songTitle: songTitle)
        }
    }

    @MainActor private func showRelocationFailure() {
        showToast("所选文件不可播放")
    }

    @MainActor private func applyRelocationUpdates(_ updates: [RelocationUpdate], songTitle: String) {
        var updated = library
        var fixed = 0
        for update in updates {
            guard let index = updated.firstIndex(where: { $0.id == update.songId }),
                  updated[index].fileURL?.standardizedFileURL.path == update.oldPath else { continue }
            updated[index].fileURL = update.newURL
            clearMissing(update.songId)
            fixed += 1
        }
        guard fixed > 0 else {
            showToast("曲目已变化，未应用重新定位")
            return
        }

        allowPersistenceAfterUserChange()
        library = updated
        showToast(fixed > 1 ? "已重新定位 \(fixed) 首曲目" : "已重新定位「\(songTitle)」")
    }

    /// 一键移除所有失效曲目，同步分组与播放上下文（spec: track-availability）
    func cleanupMissing() {
        let ids = missingIds
        guard !ids.isEmpty else { return }
        allowPersistenceAfterUserChange()
        let count = ids.count
        library.removeAll { ids.contains($0.id) }
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                group.songIds.removeAll { ids.contains($0) }
                return group
            }
        }
        for id in ids { player.handleSongRemoved(id) }
        missingIds.subtract(ids)
        showToast("已清理 \(count) 首失效曲目")
    }

    func revealInFinder(_ song: Song) {
        if let url = song.fileURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            showToast("示例曲目没有对应文件")
        }
    }

    // ── 音乐文件夹来源（spec: music-folder-sources） ──

    func addMusicFoldersViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "添加"
        guard panel.runModal() == .OK else { return }
        addMusicFolders(panel.urls)
    }

    @discardableResult
    func addMusicFolders(_ urls: [URL], startScan: Bool = true) -> Int {
        guard !urls.isEmpty else { return 0 }
        var accepted: [MusicFolderSource] = []
        var rejected = 0
        var comparisonURLs = musicFolders.compactMap(MusicFolderScanner.resolvedURL(for:))

        for url in urls {
            let canonical = MusicFolderScanner.canonicalURL(url)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: canonical.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  !comparisonURLs.contains(where: { MusicFolderScanner.pathsOverlap($0, canonical) }) else {
                rejected += 1
                continue
            }
            accepted.append(MusicFolderScanner.makeSource(for: canonical))
            comparisonURLs.append(canonical)
        }

        guard !accepted.isEmpty else {
            showToast(rejected > 0 ? "所选位置与现有音乐文件夹重复" : "未选择可用的音乐文件夹")
            return 0
        }

        allowPersistenceAfterUserChange()
        musicFolders.append(contentsOf: accepted)
        if startScan {
            scanMusicFolders(sourceIds: Set(accepted.map(\.id)), revealLibrary: true)
        } else {
            var message = "已添加 \(accepted.count) 个音乐文件夹"
            if rejected > 0 { message += "，跳过 \(rejected) 个重复位置" }
            showToast(message)
        }
        return accepted.count
    }

    func removeMusicFolder(_ sourceId: String) {
        guard let source = musicFolders.first(where: { $0.id == sourceId }) else { return }
        allowPersistenceAfterUserChange()
        musicFolders.removeAll { $0.id == sourceId }
        var updatedLibrary = library
        var changed = false
        for index in updatedLibrary.indices where updatedLibrary[index].sourceFolderId == sourceId {
            updatedLibrary[index].sourceFolderId = nil
            changed = true
        }
        if changed {
            library = updatedLibrary
        }
        showToast("已停止同步「\(source.name)」，歌曲仍保留在资料库")
    }

    func scanMusicFolders(
        sourceIds: Set<String>? = nil,
        reportCompletion: Bool = true,
        revealLibrary: Bool = false
    ) {
        let sources = sourceIds.map { ids in musicFolders.filter { ids.contains($0.id) } } ?? musicFolders
        guard !sources.isEmpty else {
            if reportCompletion {
                showToast("尚未添加音乐文件夹")
            }
            return
        }
        guard !importPhase.isImporting else {
            if reportCompletion {
                showToast("资料库任务正在进行，请稍候或先取消当前任务")
            }
            return
        }

        let librarySnapshot = library
        let albumsSnapshot = albums
        libraryActivityKind = .scanning
        importPhase = .processing(completed: 0, total: 1)
        let progress: @MainActor @Sendable (Int, Int) -> Void = { [weak self] completed, total in
            guard let self, self.importPhase.isImporting, self.libraryActivityKind == .scanning else { return }
            self.importPhase = .processing(completed: completed, total: max(total, 1))
        }
        let worker = Task.detached(priority: .utility) {
            await Self.buildFolderScanResult(
                sources: sources,
                library: librarySnapshot,
                albums: albumsSnapshot,
                progress: progress
            )
        }
        folderScanWorkerTask = worker
        importTask = Task { @MainActor [weak self] in
            let result = await worker.value
            guard let self else { return }
            defer {
                self.folderScanWorkerTask = nil
                self.importTask = nil
                self.importPhase = .idle
                self.libraryActivityKind = .importing
            }
            guard !Task.isCancelled, !worker.isCancelled else { return }
            self.applyFolderScanResult(
                result,
                reportCompletion: reportCompletion,
                revealLibrary: revealLibrary
            )
        }
    }

    nonisolated private static func buildFolderScanResult(
        sources: [MusicFolderSource],
        library: [Song],
        albums: [Album],
        progress: @MainActor @Sendable (Int, Int) -> Void
    ) async -> FolderScanResult {
        var result = FolderScanResult()
        var enumerations: [MusicFolderScanner.EnumerationResult] = []
        var scopedURLs: [(URL, Bool)] = []
        for source in sources {
            if let url = MusicFolderScanner.resolvedURL(for: source) {
                scopedURLs.append((url, url.startAccessingSecurityScopedResource()))
            }
        }
        defer {
            for (url, accessing) in scopedURLs where accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        for source in sources {
            guard !Task.isCancelled else { return result }
            do {
                let enumeration = try MusicFolderScanner.enumerate(source)
                enumerations.append(enumeration)
                result.successfulSources.append(enumeration.source)
            } catch {
                result.failedSourceNames.append(source.name)
            }
        }

        let files = enumerations.flatMap(\.files)
        await progress(0, files.count)

        var albumIdsByKey: [ImportAlbumKey: String] = [:]
        for album in albums {
            let key = ImportAlbumKey(title: album.title, artist: album.artist)
            if albumIdsByKey[key] == nil {
                albumIdsByKey[key] = album.id
            }
        }
        var albumsById = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        var imported = ImportResult()
        let existingByPath = Dictionary(
            library.compactMap { song in
                song.fileURL.map { ($0.standardizedFileURL.path, song) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let existingByIdentity = Dictionary(
            library.compactMap { song in song.fileIdentity.map { ($0, song) } },
            uniquingKeysWith: { first, _ in first }
        )
        var claimedSongIds: Set<String> = []
        var discoveredPaths: Set<String> = []
        var discoveredIdentities: Set<String> = []
        var processed = 0

        for file in files {
            guard !Task.isCancelled else { return result }
            let path = file.url.standardizedFileURL.path
            if !discoveredPaths.insert(path).inserted {
                processed += 1
                await progress(processed, files.count)
                continue
            }
            if let identity = file.identity, !discoveredIdentities.insert(identity).inserted {
                processed += 1
                await progress(processed, files.count)
                continue
            }

            var existing = existingByPath[path]
            if let pathMatch = existing, claimedSongIds.contains(pathMatch.id) {
                existing = nil
            }
            if existing == nil, let identity = file.identity,
               let identityMatch = existingByIdentity[identity],
               !claimedSongIds.contains(identityMatch.id) {
                existing = identityMatch
            }
            if let existing {
                claimedSongIds.insert(existing.id)
            }

            let metadataChanged = existing == nil
                || existing?.fileModificationDate != file.modificationDate
                || existing?.fileSize != file.size
            if metadataChanged {
                if canDecodeAudio(at: file.url),
                   let metadata = await parseMetadata(url: file.url) {
                    appendImportedSong(
                        url: file.url,
                        metadata: metadata,
                        albumIdsByKey: &albumIdsByKey,
                        albumsById: &albumsById,
                        result: &imported,
                        id: existing?.id,
                        sourceFolderId: file.sourceId,
                        fileIdentity: file.identity,
                        fileModificationDate: file.modificationDate,
                        fileSize: file.size,
                        dateAdded: existing?.dateAdded,
                        replaceExistingArtwork: existing != nil
                    )
                    if existing == nil {
                        result.addedCount += 1
                    } else {
                        result.refreshedCount += 1
                        if existing?.fileURL?.standardizedFileURL.path != path {
                            result.movedCount += 1
                        }
                    }
                } else {
                    result.skippedBroken += 1
                }
            } else if var existing {
                if existing.fileURL?.standardizedFileURL.path != path {
                    result.movedCount += 1
                }
                existing.fileURL = file.url
                existing.sourceFolderId = file.sourceId
                existing.fileIdentity = file.identity
                existing.fileModificationDate = file.modificationDate
                existing.fileSize = file.size
                result.songs.append(existing)
            }
            processed += 1
            await progress(processed, files.count)
        }

        result.songs.append(contentsOf: imported.songs)
        result.newAlbums = imported.newAlbums
        result.albumArtworkUpdates = imported.albumArtworkUpdates
        return result
    }

    @MainActor private func applyFolderScanResult(
        _ result: FolderScanResult,
        reportCompletion: Bool,
        revealLibrary: Bool
    ) {
        let successfulIds = Set(result.successfulSources.map(\.id))
        var updatedAlbums = albums
        var albumIdRemap: [String: String] = [:]

        for update in result.albumArtworkUpdates {
            guard let index = updatedAlbums.firstIndex(where: { $0.id == update.albumId }),
                  update.replacesExisting || updatedAlbums[index].artworkData == nil else { continue }
            updatedAlbums[index].artworkData = update.artworkData
        }
        for album in result.newAlbums {
            albumIdRemap[album.id] = Self.mergeImportedAlbum(album, into: &updatedAlbums)
        }
        let scannedSongs = result.songs.map { song in
            var song = song
            if let albumId = song.albumId, let remapped = albumIdRemap[albumId] {
                song.albumId = remapped
            }
            return song
        }

        var updatedLibrary = library.filter { song in
            guard let sourceId = song.sourceFolderId else { return true }
            return !successfulIds.contains(sourceId)
        }
        for scannedSong in scannedSongs {
            if let index = updatedLibrary.firstIndex(where: { $0.id == scannedSong.id }) {
                updatedLibrary[index] = scannedSong
            } else if let path = scannedSong.fileURL?.standardizedFileURL.path,
                      let index = updatedLibrary.firstIndex(where: {
                          $0.fileURL?.standardizedFileURL.path == path
                      }) {
                var adopted = scannedSong
                adopted = Song(
                    id: updatedLibrary[index].id,
                    title: adopted.title,
                    artist: adopted.artist,
                    albumId: adopted.albumId,
                    duration: adopted.duration,
                    fileURL: adopted.fileURL,
                    artworkData: adopted.artworkData,
                    sourceFolderId: adopted.sourceFolderId,
                    fileIdentity: adopted.fileIdentity,
                    fileModificationDate: adopted.fileModificationDate,
                    fileSize: adopted.fileSize,
                    dateAdded: updatedLibrary[index].dateAdded
                )
                updatedLibrary[index] = adopted
            } else {
                updatedLibrary.append(scannedSong)
            }
        }

        let oldIds = Set(library.map(\.id))
        let newIds = Set(updatedLibrary.map(\.id))
        let removedIds = oldIds.subtracting(newIds)
        let referencedAlbumIds = Set(updatedLibrary.compactMap(\.albumId))
        updatedAlbums.removeAll { !referencedAlbumIds.contains($0.id) }

        allowPersistenceAfterUserChange()
        let successfulById = Dictionary(uniqueKeysWithValues: result.successfulSources.map { ($0.id, $0) })
        musicFolders = musicFolders.map { successfulById[$0.id] ?? $0 }
        if updatedAlbums != albums {
            albums = updatedAlbums
        }
        if updatedLibrary != library {
            library = updatedLibrary
        }
        removeSongReferences(removedIds)
        for song in scannedSongs {
            clearMissing(song.id)
        }
        if revealLibrary {
            view = .library
        }

        guard reportCompletion else { return }
        let removedCount = removedIds.count
        var details: [String] = []
        if result.addedCount > 0 { details.append("新增 \(result.addedCount) 首") }
        if result.movedCount > 0 { details.append("移动 \(result.movedCount) 首") }
        if result.refreshedCount > 0 { details.append("更新 \(result.refreshedCount) 首") }
        if removedCount > 0 { details.append("移除 \(removedCount) 首") }
        if result.skippedBroken > 0 { details.append("\(result.skippedBroken) 个文件无法解码") }
        if !result.failedSourceNames.isEmpty {
            details.append("\(result.failedSourceNames.count) 个文件夹无法访问")
        }
        showToast(details.isEmpty ? "音乐文件夹已是最新" : "扫描完成：" + details.joined(separator: "，"))
    }

    private func removeSongReferences(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                group.songIds.removeAll { ids.contains($0) }
                return group
            }
        }
        for id in ids {
            player.handleSongRemoved(id)
        }
        selectedSongIds.subtract(ids)
        if let selectedId, ids.contains(selectedId) {
            self.selectedId = selectedVisibleSongs.first?.id
        }
        if let lyricsPage, ids.contains(lyricsPage.songId) {
            self.lyricsPage = nil
        }
        missingIds.subtract(ids)
    }

    // ── 导入（spec: library-import） ──

    nonisolated static func canDecodeAudio(at url: URL) -> Bool {
        AudioFileSupport.canDecode(at: url)
    }

    func importViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = AudioFileSupport.contentTypes
        panel.prompt = "导入"
        if panel.runModal() == .OK {
            importFiles(panel.urls)
        }
    }

    func importFiles(_ urls: [URL]) {
        let audioURLs = urls.filter { AudioFileSupport.isSupportedExtension($0) }
        guard !audioURLs.isEmpty else {
            showToast("未发现可导入的音频文件")
            return
        }
        guard !importPhase.isImporting else {
            showToast("音乐正在导入，请稍候或先取消当前任务")
            return
        }

        let existingPaths = Set(library.compactMap { $0.fileURL?.standardizedFileURL.path })
        let albumsSnapshot = albums
        libraryActivityKind = .importing
        importPhase = .processing(completed: 0, total: audioURLs.count)

        let progress: @MainActor @Sendable (Int) -> Void = { [weak self] completed in
            guard let self, self.importPhase.isImporting else { return }
            self.importPhase = .processing(completed: completed, total: audioURLs.count)
        }
        let worker = Task.detached(priority: .userInitiated) {
            await Self.buildImportResult(
                urls: audioURLs,
                existingPaths: existingPaths,
                albums: albumsSnapshot,
                progress: progress
            )
        }
        importWorkerTask = worker
        importTask = Task { @MainActor [weak self] in
            let result = await worker.value
            guard let self else { return }
            defer {
                self.importWorkerTask = nil
                self.importTask = nil
                self.importPhase = .idle
            }
            guard !Task.isCancelled, !worker.isCancelled else { return }
            self.applyImportResult(result)
        }
    }

    func cancelImport() {
        guard importPhase.isImporting else { return }
        let cancellationMessage = libraryActivityKind.cancellationMessage
        importWorkerTask?.cancel()
        folderScanWorkerTask?.cancel()
        importTask?.cancel()
        importWorkerTask = nil
        folderScanWorkerTask = nil
        importTask = nil
        importPhase = .idle
        libraryActivityKind = .importing
        showToast(cancellationMessage)
    }

    @MainActor private func applyImportResult(_ result: ImportResult) {
        var updatedAlbums = albums
        var albumIdRemap: [String: String] = [:]

        for update in result.albumArtworkUpdates {
            guard let index = updatedAlbums.firstIndex(where: { $0.id == update.albumId }),
                  update.replacesExisting || updatedAlbums[index].artworkData == nil else { continue }
            updatedAlbums[index].artworkData = update.artworkData
        }
        for album in result.newAlbums {
            let resolvedId = Self.mergeImportedAlbum(album, into: &updatedAlbums)
            albumIdRemap[album.id] = resolvedId
        }

        let remappedSongs = result.songs.map { song in
            var song = song
            if let albumId = song.albumId, let resolvedId = albumIdRemap[albumId] {
                song.albumId = resolvedId
            }
            return song
        }
        let currentPaths = Set(library.compactMap { $0.fileURL?.standardizedFileURL.path })
        let songsToAdd = remappedSongs.filter { song in
            guard let path = song.fileURL?.standardizedFileURL.path else { return true }
            return !currentPaths.contains(path)
        }
        let skippedExisting = result.skippedExisting + (remappedSongs.count - songsToAdd.count)

        if !songsToAdd.isEmpty {
            allowPersistenceAfterUserChange()
            if updatedAlbums != albums {
                albums = updatedAlbums
            }
            library.append(contentsOf: songsToAdd)
            for song in songsToAdd {
                clearMissing(song.id)
            }
            view = .library
            var msg = "已导入 \(songsToAdd.count) 首歌曲"
            if skippedExisting > 0 { msg += "，跳过 \(skippedExisting) 首已存在" }
            if result.skippedBroken > 0 { msg += "，\(result.skippedBroken) 个文件无法解码" }
            showToast(msg)
        } else if skippedExisting > 0 {
            showToast("文件已在资料库中")
        } else if result.skippedBroken > 0 {
            showToast("\(result.skippedBroken) 个文件无法解码")
        } else {
            showToast("未发现可导入的音频文件")
        }
    }

    nonisolated private static func buildImportResult(
        urls: [URL],
        existingPaths: Set<String>,
        albums: [Album],
        progress: @MainActor @Sendable (Int) -> Void
    ) async -> ImportResult {
        var result = ImportResult()
        var seenPaths = Set<String>()
        var albumIdsByKey: [ImportAlbumKey: String] = [:]
        for album in albums {
            let key = ImportAlbumKey(title: album.title, artist: album.artist)
            if albumIdsByKey[key] == nil {
                albumIdsByKey[key] = album.id
            }
        }
        var albumsById = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })

        var processed = 0
        for url in urls {
            guard !Task.isCancelled else { break }
            let path = url.standardizedFileURL.path
            if existingPaths.contains(path) || !seenPaths.insert(path).inserted {
                result.skippedExisting += 1
            } else if !canDecodeAudio(at: url) {
                result.skippedBroken += 1
            } else if let metadata = await parseMetadata(url: url) {
                appendImportedSong(
                    url: url,
                    metadata: metadata,
                    albumIdsByKey: &albumIdsByKey,
                    albumsById: &albumsById,
                    result: &result
                )
            } else {
                result.skippedBroken += 1
            }
            processed += 1
            await progress(processed)
        }

        return result
    }

    nonisolated private static func appendImportedSong(
        url: URL,
        metadata: ParsedMetadata,
        albumIdsByKey: inout [ImportAlbumKey: String],
        albumsById: inout [String: Album],
        result: inout ImportResult,
        id: String? = nil,
        sourceFolderId: String? = nil,
        fileIdentity: String? = nil,
        fileModificationDate: Date? = nil,
        fileSize: Int64? = nil,
        dateAdded: Date? = nil,
        replaceExistingArtwork: Bool = false
    ) {
        var albumId: String?
        let artworkData = metadata.embeddedArtworkData ?? metadata.sidecarArtworkData
        if let albumName = metadata.albumName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !albumName.isEmpty {
            let artist = metadata.artist ?? "未知艺人"
            albumId = albumIdForImport(
                title: albumName,
                artist: artist,
                artworkData: artworkData,
                albumIdsByKey: &albumIdsByKey,
                albumsById: &albumsById,
                result: &result,
                replaceExistingArtwork: replaceExistingArtwork
            )
        }

        result.songs.append(Song(
            id: id ?? "imp-" + UUID().uuidString,
            title: metadata.title,
            artist: metadata.artist,
            albumId: albumId,
            duration: metadata.duration,
            fileURL: url,
            artworkData: metadata.sidecarArtworkData ?? (albumId == nil ? metadata.embeddedArtworkData : nil),
            sourceFolderId: sourceFolderId,
            fileIdentity: fileIdentity,
            fileModificationDate: fileModificationDate,
            fileSize: fileSize,
            dateAdded: dateAdded ?? (id == nil ? Date() : nil)
        ))
    }

    nonisolated static func mergeImportedAlbum(_ candidate: Album, into albums: inout [Album]) -> String {
        let candidateKey = normalizedImportAlbumKey(title: candidate.title, artist: candidate.artist)
        if let index = albums.firstIndex(where: {
            normalizedImportAlbumKey(title: $0.title, artist: $0.artist) == candidateKey
        }) {
            if albums[index].artworkData == nil, let artworkData = candidate.artworkData {
                albums[index].artworkData = artworkData
            }
            return albums[index].id
        }
        albums.append(candidate)
        return candidate.id
    }

    nonisolated private static func normalizedImportAlbumKey(title: String, artist: String) -> String {
        "\(title.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))\u{1F}\(artist.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
    }

    nonisolated private static func albumIdForImport(
        title: String,
        artist: String,
        artworkData: Data?,
        albumIdsByKey: inout [ImportAlbumKey: String],
        albumsById: inout [String: Album],
        result: inout ImportResult,
        replaceExistingArtwork: Bool = false
    ) -> String {
        let key = ImportAlbumKey(title: title, artist: artist)
        if let albumId = albumIdsByKey[key] {
            if let artworkData,
               replaceExistingArtwork || albumsById[albumId]?.artworkData == nil {
                albumsById[albumId]?.artworkData = artworkData
                result.albumArtworkUpdates.append(AlbumArtworkUpdate(
                    albumId: albumId,
                    artworkData: artworkData,
                    replacesExisting: replaceExistingArtwork
                ))
            }
            return albumId
        }

        var hash: UInt64 = 5381
        for b in (title + artist).utf8 { hash = hash &* 33 &+ UInt64(b) }
        let h1 = Double(hash % 360)
        let h2 = (h1 + 40).truncatingRemainder(dividingBy: 360)
        let album = Album(
            id: "alb-" + UUID().uuidString,
            title: title,
            artist: artist,
            year: Calendar.current.component(.year, from: .now),
            artworkData: artworkData,
            h1: h1,
            h2: h2
        )
        albumIdsByKey[key] = album.id
        albumsById[album.id] = album
        result.newAlbums.append(album)
        return album.id
    }

    /// 读取元数据：标题/艺术家/专辑/真实时长/封面，缺失回退（spec: 元数据解析）
    nonisolated private static func parseMetadata(url: URL) async -> ParsedMetadata? {
        let filenameStem = url.deletingPathExtension().lastPathComponent
        let asset = AVURLAsset(url: url)
        var title = filenameStem
        var hasMetadataTitle = false
        var artist: String?
        var albumName: String?
        var artworkData: Data?
        var sidecarArtworkData: Data?
        var duration: Double = 0

        if let d = try? await asset.load(.duration) {
            duration = d.seconds.isFinite ? d.seconds : 0
        }
        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let value = try? await item.load(.stringValue) {
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            title = trimmed
                            hasMetadataTitle = true
                        }
                    }
                case .commonKeyArtist:
                    if let value = try? await item.load(.stringValue) {
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        artist = trimmed.isEmpty ? nil : trimmed
                    }
                case .commonKeyAlbumName:
                    albumName = try? await item.load(.stringValue)
                case .commonKeyArtwork:
                    if artworkData == nil,
                       let data = try? await item.load(.dataValue),
                       let prepared = await Self.preparedArtworkData(data) {
                        artworkData = prepared
                    }
                default: break
                }
            }
        }
        if artworkData == nil {
            sidecarArtworkData = await Self.sidecarArtworkData(for: url)
            artworkData = sidecarArtworkData
        }
        let fallback = metadataWithFilenameFallback(
            filenameStem: filenameStem,
            title: title,
            hasMetadataTitle: hasMetadataTitle,
            artist: artist
        )

        return ParsedMetadata(
            title: fallback.title,
            artist: fallback.artist,
            albumName: albumName,
            duration: duration,
            embeddedArtworkData: artworkData,
            sidecarArtworkData: sidecarArtworkData
        )
    }

    nonisolated static func metadataWithFilenameFallback(
        filenameStem: String,
        title: String,
        hasMetadataTitle: Bool,
        artist: String?
    ) -> FilenameMetadata {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = trimmedTitle.isEmpty ? filenameStem : trimmedTitle
        let trimmedArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedArtist, !trimmedArtist.isEmpty {
            return FilenameMetadata(title: safeTitle, artist: trimmedArtist)
        }
        guard let filenameMetadata = metadataFromFilenameStem(filenameStem) else {
            return FilenameMetadata(title: safeTitle, artist: nil)
        }
        return FilenameMetadata(
            title: hasMetadataTitle ? safeTitle : filenameMetadata.title,
            artist: filenameMetadata.artist
        )
    }

    nonisolated static func metadataFromFilenameStem(_ stem: String) -> FilenameMetadata? {
        let pattern = #"^(.+)\s+[-–—－]\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(stem.startIndex..<stem.endIndex, in: stem)
        guard let match = regex.firstMatch(in: stem, range: range),
              match.numberOfRanges == 3,
              let titleRange = Range(match.range(at: 1), in: stem),
              let artistRange = Range(match.range(at: 2), in: stem) else { return nil }
        let title = String(stem[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = String(stem[artistRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !artist.isEmpty else { return nil }
        return FilenameMetadata(title: title, artist: artist)
    }

    static func songsWithFilenameMetadataFallback(_ songs: [Song]) -> [Song] {
        songs.map { song in
            var updated = song
            guard let fileURL = song.fileURL else { return updated }
            let trimmedArtist = song.artist?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedArtist?.isEmpty ?? true else { return updated }

            let filenameStem = fileURL.deletingPathExtension().lastPathComponent
            let fallback = metadataWithFilenameFallback(
                filenameStem: filenameStem,
                title: song.title,
                hasMetadataTitle: song.title != filenameStem,
                artist: song.artist
            )
            updated.title = fallback.title
            updated.artist = fallback.artist
            return updated
        }
    }

    private static func isValidArtworkData(_ data: Data) -> Bool {
        !data.isEmpty && NSImage(data: data) != nil
    }

    private static func preparedArtworkData(_ data: Data) -> Data? {
        guard !data.isEmpty, let image = NSImage(data: data) else { return nil }
        let pixelSize = image.representations.reduce(CGSize(width: image.size.width, height: image.size.height)) { best, rep in
            let repSize = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            return repSize.width * repSize.height > best.width * best.height ? repSize : best
        }
        let longestSide = max(pixelSize.width, pixelSize.height)
        if data.count <= maxArtworkDataSize, longestSide <= CGFloat(maxArtworkPixelLength) {
            return data
        }

        let scale = longestSide > 0 ? min(1, CGFloat(maxArtworkPixelLength) / longestSide) : 1
        let targetWidth = max(1, Int((pixelSize.width * scale).rounded()))
        let targetHeight = max(1, Int((pixelSize.height * scale).rounded()))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetWidth,
            pixelsHigh: targetHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(
            in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]),
              jpegData.count <= maxArtworkDataSize,
              isValidArtworkData(jpegData) else { return nil }
        return jpegData
    }

    nonisolated private static func sidecarArtworkData(for audioURL: URL) async -> Data? {
        let baseURL = audioURL.deletingPathExtension()
        let extensions = ["jpg", "jpeg", "png", "webp", "JPG", "JPEG", "PNG", "WEBP"]
        for ext in extensions {
            let imageURL = baseURL.appendingPathExtension(ext)
            guard FileManager.default.fileExists(atPath: imageURL.path),
                  let data = try? Data(contentsOf: imageURL),
                  let prepared = await preparedArtworkData(data) else { continue }
            return prepared
        }
        return nil
    }

    private static func isFavoritesGroupId(_ id: String) -> Bool {
        id == favoritesGroupId
    }

    private static func normalizedSystemGroups(_ groups: [Playlist]) -> [Playlist] {
        var favorites = groups.first { isFavoritesGroupId($0.id) }
            ?? Playlist(id: favoritesGroupId, name: favoritesGroupName, songIds: [])
        favorites.name = favoritesGroupName
        favorites.songIds = uniqueSongIds(favorites.songIds)

        let ordinaryGroups = groups.filter { !isFavoritesGroupId($0.id) }
        return [favorites] + ordinaryGroups
    }

    private static func uniqueSongIds(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids.filter { seen.insert($0).inserted }
    }

    private func updatePlaylists(_ transform: ([Playlist]) -> [Playlist]) {
        playlists = Self.normalizedSystemGroups(transform(playlists))
    }

    private func backfillSidecarArtwork() {
        let snapshot: [(String, URL, String)] = library.compactMap { song in
            guard song.artworkData == nil, let fileURL = song.fileURL else { return nil }
            return (song.id, fileURL, fileURL.standardizedFileURL.path)
        }
        guard !snapshot.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self, snapshot] in
            var backfills: [BackfilledArtwork] = []
            for (id, fileURL, path) in snapshot {
                guard let data = await Self.sidecarArtworkData(for: fileURL) else { continue }
                backfills.append(BackfilledArtwork(songId: id, path: path, artworkData: data))
            }
            await self?.applyBackfilledArtwork(backfills)
        }
    }

    @MainActor private func applyBackfilledArtwork(_ backfills: [BackfilledArtwork]) {
        guard !backfills.isEmpty else { return }
        let dataById = Dictionary(uniqueKeysWithValues: backfills.map { ($0.songId, $0) })
        var updated = library
        var changed = false
        for index in updated.indices {
            guard updated[index].artworkData == nil,
                  let fileURL = updated[index].fileURL,
                  let backfill = dataById[updated[index].id],
                  fileURL.standardizedFileURL.path == backfill.path else { continue }
            updated[index].artworkData = backfill.artworkData
            changed = true
        }
        if changed {
            library = updated
        }
    }

    // ── 持久化（design.md D6：JSON 存 Application Support） ──

    private struct PersistedLibrary: Codable, Sendable {
        var albums: [Album]
        var songs: [Song]
        var playlists: [Playlist]
        var musicFolders: [MusicFolderSource]

        private enum CodingKeys: String, CodingKey {
            case albums, songs, playlists, musicFolders
        }

        init(
            albums: [Album],
            songs: [Song],
            playlists: [Playlist],
            musicFolders: [MusicFolderSource]
        ) {
            self.albums = albums
            self.songs = songs
            self.playlists = playlists
            self.musicFolders = musicFolders
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            albums = try container.decode([Album].self, forKey: .albums)
            songs = try container.decode([Song].self, forKey: .songs)
            playlists = try container.decode([Playlist].self, forKey: .playlists)
            musicFolders = try container.decodeIfPresent([MusicFolderSource].self, forKey: .musicFolders) ?? []
        }
    }

    private static var stripsBundledSampleData: Bool {
        if let override = stripsBundledSampleDataOverride {
            return override
        }
#if DEBUG
        return false
#else
        return true
#endif
    }

    private static func sanitizedPersistedLibrary(_ persisted: PersistedLibrary) -> PersistedLibrary {
        guard stripsBundledSampleData else { return persisted }

        let songs = persisted.songs.filter { $0.fileURL != nil }
        guard songs.count != persisted.songs.count else { return persisted }

        let songIds = Set(songs.map(\.id))
        let albumIds = Set(songs.compactMap(\.albumId))
        let albums = persisted.albums.filter { albumIds.contains($0.id) }
        let playlists = persisted.playlists.map { playlist in
            var playlist = playlist
            playlist.songIds = playlist.songIds.filter { songIds.contains($0) }
            return playlist
        }.filter { playlist in
            isFavoritesGroupId(playlist.id) || !playlist.songIds.isEmpty
        }

        return PersistedLibrary(
            albums: albums,
            songs: songs,
            playlists: playlists,
            musicFolders: persisted.musicFolders
        )
    }

    private var currentPersistenceSnapshot: PersistedLibrary {
        PersistedLibrary(
            albums: albums,
            songs: library,
            playlists: playlists,
            musicFolders: musicFolders
        )
    }

    private static var storeURL: URL {
        let dir = storeDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }

    private static var playbackMemoryURL: URL {
        let dir = storeDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("playback-memory.json")
    }

    private static var storeDirectory: URL {
        storeDirectoryOverride
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Crate", isDirectory: true)
    }

    private func persist() {
        guard loaded, persistenceEnabled, !persistenceProtectionActive else { return }
        schedulePersistence(currentPersistenceSnapshot)
    }

    private func allowPersistenceAfterUserChange() {
        persistenceProtectionActive = false
    }

    private func schedulePersistence(_ snapshot: PersistedLibrary) {
        var shouldScheduleDrain = false
        persistenceLock.lock()
        pendingPersistenceSnapshot = snapshot
        persistenceGeneration &+= 1
        if !persistenceDrainScheduled {
            persistenceDrainScheduled = true
            shouldScheduleDrain = true
        }
        persistenceLock.unlock()

        guard shouldScheduleDrain else { return }
        Self.persistenceQueue.async {
            self.drainPersistenceQueue()
        }
    }

    nonisolated private func drainPersistenceQueue() {
        while true {
            let snapshot: PersistedLibrary
            let generation: Int

            persistenceLock.lock()
            guard let pendingPersistenceSnapshot else {
                persistenceDrainScheduled = false
                persistenceLock.unlock()
                return
            }
            snapshot = pendingPersistenceSnapshot
            generation = persistenceGeneration
            persistenceLock.unlock()

            do {
                try Self.writePersistenceSnapshot(snapshot, to: persistenceStoreURL)
                markPersistenceWriteSucceeded()
            } catch {
                reportPersistenceWriteFailure(error)
            }

            persistenceLock.lock()
            if persistenceGeneration == generation {
                persistenceDrainScheduled = false
                persistenceLock.unlock()
                return
            }
            persistenceLock.unlock()
        }
    }

    nonisolated private func reportPersistenceWriteFailure(_ error: Error) {
        Task { @MainActor [weak self] in
            guard let self, !self.persistenceFailureReported else { return }
            self.persistenceFailureReported = true
            self.showToast("曲库保存失败，请检查磁盘权限或空间")
        }
    }

    nonisolated private func markPersistenceWriteSucceeded() {
        Task { @MainActor [weak self] in
            self?.persistenceFailureReported = false
        }
    }

    nonisolated private static func writePersistenceSnapshot(_ snapshot: PersistedLibrary, to url: URL) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - 时间格式化（player-ui.jsx formatTime / formatTotal）

func formatTime(_ sec: Double?) -> String {
    guard let sec, sec.isFinite else { return "-:--" }
    let s = Int(max(0, sec.rounded()))
    return "\(s / 60):" + String(format: "%02d", s % 60)
}

func formatTotal(_ seconds: Double) -> String {
    let min = Int((seconds / 60).rounded())
    if min < 60 { return "\(min) 分钟" }
    return "\(min / 60) 小时 \(min % 60) 分钟"
}
