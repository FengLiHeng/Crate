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

@Observable
final class AppState {
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

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "lmp-theme")
        theme = AppTheme(rawValue: savedTheme ?? "") ?? .light

        if let data = try? Data(contentsOf: Self.storeURL),
           let persisted = try? JSONDecoder().decode(PersistedLibrary.self, from: data) {
            albums = persisted.albums
            library = persisted.songs
            playlists = persisted.playlists
        } else {
            albums = SampleData.albums
            library = SampleData.songs
            playlists = SampleData.playlists
        }
        loaded = true
        // init 中赋值不触发 didSet，手动建一次索引
        albumsById = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        songsById = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })

        player.songProvider = { [weak self] id in self?.songsById[id] }
        player.onToast = { [weak self] msg in self?.showToast(msg) }
        player.onMissing = { [weak self] id in self?.markMissing(id) }

        // 启动后台批量探测失效曲目（design.md D2）
        probeAvailability()
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

    // ── 当前视图歌曲（含搜索过滤，对应 player-app.jsx viewSongs） ──
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

    var viewSongs: [Song] {
        var list: [Song]
        if let pl = viewPlaylist {
            let byId = songsById
            list = pl.songIds.compactMap { byId[$0] }
        } else {
            list = library
        }
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

    func addSong(_ song: Song, to playlist: Playlist) {
        if playlist.songIds.contains(song.id) {
            showToast("「\(song.title)」已在「\(playlist.name)」中")
            return
        }
        playlists = playlists.map { p in
            var p = p
            if p.id == playlist.id { p.songIds.append(song.id) }
            return p
        }
        showToast("已添加到「\(playlist.name)」")
    }

    func removeSong(_ song: Song) {
        library.removeAll { $0.id == song.id }
        playlists = playlists.map { p in
            var p = p
            p.songIds.removeAll { $0 == song.id }
            return p
        }
        player.handleSongRemoved(song.id)
        showToast("已从资料库中删除「\(song.title)」")
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

    /// 一键移除所有失效曲目，同步歌单与播放上下文（spec: track-availability）
    func cleanupMissing() {
        let ids = missingIds
        guard !ids.isEmpty else { return }
        let count = ids.count
        library.removeAll { ids.contains($0.id) }
        playlists = playlists.map { p in
            var p = p
            p.songIds.removeAll { ids.contains($0) }
            return p
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
        panel.allowedContentTypes = [.audio]
        panel.prompt = "导入"
        if panel.runModal() == .OK {
            importFiles(panel.urls)
        }
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

    /// 读取元数据：标题/艺术家/专辑/真实时长，缺失回退（spec: 元数据解析）
    private func parseMetadata(url: URL) async -> Song? {
        let asset = AVURLAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist: String?
        var albumName: String?
        var duration: Double = 0

        if let d = try? await asset.load(.duration) {
            duration = d.seconds.isFinite ? d.seconds : 0
        }
        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let key = item.commonKey else { continue }
                let value = try? await item.load(.stringValue)
                switch key {
                case .commonKeyTitle: if let v = value, !v.isEmpty { title = v }
                case .commonKeyArtist: artist = value
                case .commonKeyAlbumName: albumName = value
                default: break
                }
            }
        }

        var albumId: String?
        if let albumName, !albumName.isEmpty {
            albumId = findOrCreateAlbum(title: albumName, artist: artist ?? "未知艺人")
        }

        return Song(
            id: "imp-" + UUID().uuidString,
            title: title,
            artist: artist,
            albumId: albumId,
            duration: duration,
            fileURL: url
        )
    }

    /// 按专辑名+艺人复用或创建专辑，封面色相由名称稳定散列生成
    private func findOrCreateAlbum(title: String, artist: String) -> String {
        if let existing = albums.first(where: { $0.title == title && $0.artist == artist }) {
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

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Crate", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }

    private func persist() {
        guard loaded else { return }
        let snapshot = PersistedLibrary(albums: albums, songs: library, playlists: playlists)
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
