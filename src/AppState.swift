import SwiftUI
import Observation
import AVFoundation
import UniformTypeIdentifiers

enum LibraryView: Hashable {
    case library
    case playlist(String)
}

enum RepeatMode: String {
    case off, all, one
}

enum GroupNameValidation {
    static let maxLength = 24
}

@Observable
final class AppState {
    static let favoritesGroupId = "system-favorites"
    static let favoritesGroupName = "我的收藏"
    private static let persistenceQueue = DispatchQueue(label: "com.crate.library-persistence", qos: .utility)

    // ── 主题（持久化键与设计稿 localStorage 对齐） ──
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "lmp-theme") }
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

    // 索引缓存：随数据变更重建，避免每次渲染/查询全量建字典
    private(set) var albumsById: [String: Album] = [:]
    private(set) var songsById: [String: Song] = [:]

    // ── 视图状态 ──
    var view: LibraryView = .library
    var search = ""
    var selectedId: String?
    var queueOpen = false
    var toast: String?
    var dragOver = false

    // ── 失效曲目（运行时派生，不持久化；design.md D1） ──
    var missingIds: Set<String> = []

    // ── 播放 ──
    let player = PlayerStore()

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private let persistenceLock = NSLock()
    @ObservationIgnored private var pendingPersistenceSnapshot: PersistedLibrary?
    @ObservationIgnored private var persistenceGeneration = 0
    @ObservationIgnored private var persistenceDrainScheduled = false

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "lmp-theme")
        theme = AppTheme(rawValue: savedTheme ?? "") ?? .light

        if let data = try? Data(contentsOf: Self.storeURL),
           let persisted = try? JSONDecoder().decode(PersistedLibrary.self, from: data) {
            albums = persisted.albums
            library = persisted.songs
            playlists = Self.normalizedSystemGroups(persisted.playlists)
        } else {
            albums = []
            library = []
            playlists = Self.normalizedSystemGroups([])
        }
        loaded = true
        // init 中赋值不触发 didSet，手动建一次索引
        albumsById = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        songsById = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })
        persist()
        backfillSidecarArtwork()

        player.songProvider = { [weak self] id in self?.songsById[id] }
        player.onToast = { [weak self] msg in self?.showToast(msg) }
        player.onMissing = { [weak self] id in self?.markMissing(id) }

        // 启动后台批量探测失效曲目（design.md D2）
        probeAvailability()
    }

    func flushPersistence() {
        guard loaded else { return }
        let snapshot = currentPersistenceSnapshot
        persistenceLock.lock()
        pendingPersistenceSnapshot = snapshot
        persistenceGeneration &+= 1
        persistenceLock.unlock()

        Self.persistenceQueue.sync { [weak self] in
            Self.writePersistenceSnapshot(snapshot)
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
        let snapshot: [(String, String)] = library.compactMap { song in
            song.fileURL.map { (song.id, $0.path) }
        }
        Task.detached(priority: .utility) { [weak self] in
            var missing: Set<String> = []
            for (id, path) in snapshot where !FileManager.default.fileExists(atPath: path) {
                missing.insert(id)
            }
            await self?.applyMissing(missing)
        }
    }

    @MainActor private func applyMissing(_ ids: Set<String>) { missingIds = ids }

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
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { s in
                let album = s.albumId.flatMap { albumsById[$0] }
                let artist = s.artist ?? album?.artist ?? ""
                return s.title.lowercased().contains(q)
                    || artist.lowercased().contains(q)
                    || (album?.title.lowercased().contains(q) ?? false)
            }
        }
        return list
    }

    func artistName(for song: Song) -> String {
        song.artist ?? song.albumId.flatMap { albumsById[$0]?.artist } ?? "未知艺人"
    }

    func albumTitle(for song: Song) -> String {
        song.albumId.flatMap { albumsById[$0]?.title } ?? "未知专辑"
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
        updatePlaylists { groups in groups.filter { $0.id != groupId } }
        if case .playlist(let id) = view, id == groupId {
            view = .library
        }
        showToast("已删除分组「\(group.name)」")
    }

    func moveGroup(_ groupId: String, to destinationIndex: Int) {
        guard !Self.isFavoritesGroupId(groupId) else { return }
        guard let sourceIndex = playlists.firstIndex(where: { $0.id == groupId }) else { return }
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
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                if group.id == current.id { group.songIds.append(song.id) }
                return group
            }
        }
        showToast("已添加到分组「\(current.name)」")
    }

    func removeSong(_ song: Song) {
        library.removeAll { $0.id == song.id }
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                group.songIds.removeAll { $0 == song.id }
                return group
            }
        }
        player.handleSongRemoved(song.id)
        showToast("已从资料库中删除「\(song.title)」")
    }

    func removeSong(_ song: Song, from playlist: Playlist) {
        guard playlists.contains(where: { $0.id == playlist.id && $0.songIds.contains(song.id) }) else { return }
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                if group.id == playlist.id {
                    group.songIds.removeAll { $0 == song.id }
                }
                return group
            }
        }
        if selectedId == song.id {
            selectedId = nil
        }
        showToast("已从分组「\(playlist.name)」移除")
    }

    func clearLibrary() {
        let count = library.count
        guard count > 0 else { return }

        player.resetPlaybackSession()
        albums = []
        library = []
        updatePlaylists { groups in
            groups.map { group in
                var group = group
                group.songIds = []
                return group
            }
        }
        missingIds.removeAll()
        view = .library
        selectedId = nil
        search = ""
        showToast("已清空歌曲列表（\(count) 首）")
    }

    /// 为失效曲目重新定位文件，并自动批量修复同一旧目录下的其他失效曲目（spec: track-availability，design.md D6）
    func relocate(_ song: Song) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.prompt = "重新定位"
        guard panel.runModal() == .OK, let newURL = panel.urls.first else { return }
        guard let oldURL = song.fileURL else { return }

        let oldDir = oldURL.deletingLastPathComponent().standardizedFileURL.path
        let newDir = newURL.deletingLastPathComponent()
        var updated = library
        var fixed = 0
        for i in updated.indices {
            let s = updated[i]
            if s.id == song.id {
                updated[i].fileURL = newURL
                clearMissing(s.id)
                fixed += 1
                continue
            }
            // 仅修复同一旧目录、且新目录下存在同名文件的其他失效曲目
            guard missingIds.contains(s.id), let sURL = s.fileURL,
                  sURL.deletingLastPathComponent().standardizedFileURL.path == oldDir else { continue }
            let candidate = newDir.appendingPathComponent(sURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: candidate.path) {
                updated[i].fileURL = candidate
                clearMissing(s.id)
                fixed += 1
            }
        }
        library = updated
        showToast(fixed > 1 ? "已重新定位 \(fixed) 首曲目" : "已重新定位「\(song.title)」")
    }

    /// 一键移除所有失效曲目，同步分组与播放上下文（spec: track-availability）
    func cleanupMissing() {
        let ids = missingIds
        guard !ids.isEmpty else { return }
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

    // ── 导入（spec: library-import） ──

    static let audioExtensions: Set<String> = ["mp3", "m4a", "flac", "wav", "aac", "ogg", "aiff"]

    func importViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio]
        panel.prompt = "导入"
        if panel.runModal() == .OK {
            importFiles(panel.urls)
        }
    }

    func importFolderViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "导入文件夹"
        guard panel.runModal() == .OK, let folderURL = panel.urls.first else { return }

        let keys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            showToast("未发现可导入的音频文件")
            return
        }

        let fileURLs = urls.filter { url in
            guard (try? url.resourceValues(forKeys: keys).isRegularFile) == true else { return false }
            return true
        }
        importFiles(fileURLs)
    }

    func importFiles(_ urls: [URL]) {
        let audioURLs = urls.filter { Self.audioExtensions.contains($0.pathExtension.lowercased()) }
        guard !audioURLs.isEmpty else {
            showToast("未发现可导入的音频文件")
            return
        }
        Task { @MainActor in
            var newSongs: [Song] = []
            var skippedExisting = 0
            var skippedBroken = 0
            let existingPaths = Set(library.compactMap { $0.fileURL?.standardizedFileURL.path })

            for url in audioURLs {
                let path = url.standardizedFileURL.path
                if existingPaths.contains(path) || newSongs.contains(where: { $0.fileURL?.standardizedFileURL.path == path }) {
                    skippedExisting += 1
                    continue
                }
                // 校验可解码（design.md 风险项）
                guard (try? AVAudioPlayer(contentsOf: url)) != nil else {
                    skippedBroken += 1
                    continue
                }
                if let song = await parseMetadata(url: url) {
                    newSongs.append(song)
                }
            }

            if !newSongs.isEmpty {
                library.append(contentsOf: newSongs)
                view = .library
                var msg = "已导入 \(newSongs.count) 首歌曲"
                if skippedExisting > 0 { msg += "，跳过 \(skippedExisting) 首已存在" }
                if skippedBroken > 0 { msg += "，\(skippedBroken) 个文件无法解码" }
                showToast(msg)
            } else if skippedExisting > 0 {
                showToast("文件已在资料库中")
            } else {
                showToast("未发现可导入的音频文件")
            }
        }
    }

    /// 读取元数据：标题/艺术家/专辑/真实时长/封面，缺失回退（spec: 元数据解析）
    private func parseMetadata(url: URL) async -> Song? {
        let asset = AVURLAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
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
                    if let value = try? await item.load(.stringValue), !value.isEmpty { title = value }
                case .commonKeyArtist:
                    artist = try? await item.load(.stringValue)
                case .commonKeyAlbumName:
                    albumName = try? await item.load(.stringValue)
                case .commonKeyArtwork:
                    if artworkData == nil,
                       let data = try? await item.load(.dataValue),
                       Self.isValidArtworkData(data) {
                        artworkData = data
                    }
                default: break
                }
            }
        }
        if artworkData == nil {
            sidecarArtworkData = Self.sidecarArtworkData(for: url)
            artworkData = sidecarArtworkData
        }

        var albumId: String?
        if let albumName, !albumName.isEmpty {
            albumId = findOrCreateAlbum(title: albumName, artist: artist ?? "未知艺人", artworkData: artworkData)
        }

        return Song(
            id: "imp-" + UUID().uuidString,
            title: title,
            artist: artist,
            albumId: albumId,
            duration: duration,
            fileURL: url,
            artworkData: sidecarArtworkData ?? (albumId == nil ? artworkData : nil)
        )
    }

    private static func isValidArtworkData(_ data: Data) -> Bool {
        !data.isEmpty && NSImage(data: data) != nil
    }

    private static func sidecarArtworkData(for audioURL: URL) -> Data? {
        let baseURL = audioURL.deletingPathExtension()
        let extensions = ["jpg", "jpeg", "png", "webp", "JPG", "JPEG", "PNG", "WEBP"]
        for ext in extensions {
            let imageURL = baseURL.appendingPathExtension(ext)
            guard FileManager.default.fileExists(atPath: imageURL.path),
                  let data = try? Data(contentsOf: imageURL),
                  isValidArtworkData(data) else { continue }
            return data
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
        var updated = library
        var changed = false
        for index in updated.indices {
            guard updated[index].artworkData == nil,
                  let fileURL = updated[index].fileURL,
                  let data = Self.sidecarArtworkData(for: fileURL) else { continue }
            updated[index].artworkData = data
            changed = true
        }
        if changed {
            library = updated
        }
    }

    /// 按专辑名+艺人复用或创建专辑，封面色相由名称稳定散列生成
    private func findOrCreateAlbum(title: String, artist: String, artworkData: Data?) -> String {
        if let index = albums.firstIndex(where: { $0.title == title && $0.artist == artist }) {
            let existing = albums[index]
            if existing.artworkData == nil, let artworkData {
                albums[index].artworkData = artworkData
            }
            return existing.id
        }
        var hash: UInt64 = 5381
        for b in (title + artist).utf8 { hash = hash &* 33 &+ UInt64(b) }
        let h1 = Double(hash % 360)
        let h2 = (h1 + 40).truncatingRemainder(dividingBy: 360)
        let album = Album(
            id: "alb-" + UUID().uuidString,
            title: title, artist: artist,
            year: Calendar.current.component(.year, from: .now),
            artworkData: artworkData,
            h1: h1, h2: h2
        )
        albums.append(album)
        return album.id
    }

    // ── 持久化（design.md D6：JSON 存 Application Support） ──

    private struct PersistedLibrary: Codable {
        var albums: [Album]
        var songs: [Song]
        var playlists: [Playlist]
    }

    private var currentPersistenceSnapshot: PersistedLibrary {
        PersistedLibrary(albums: albums, songs: library, playlists: playlists)
    }

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Crate", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }

    private func persist() {
        guard loaded else { return }
        schedulePersistence(currentPersistenceSnapshot)
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

    private func drainPersistenceQueue() {
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

            Self.writePersistenceSnapshot(snapshot)

            persistenceLock.lock()
            if persistenceGeneration == generation {
                persistenceDrainScheduled = false
                persistenceLock.unlock()
                return
            }
            persistenceLock.unlock()
        }
    }

    private static func writePersistenceSnapshot(_ snapshot: PersistedLibrary) {
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: Self.storeURL, options: .atomic)
        }
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
