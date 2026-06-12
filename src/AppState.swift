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
    }

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
