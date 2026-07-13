import SwiftUI
import AppKit

// 六列网格（player.css .thead/.row）：# 44 | 标题 2.1fr | 艺术家 1.1fr | 专辑 1.1fr | 时长 56 | 更多 40
private struct ColumnWidths {
    let title: CGFloat
    let artist: CGFloat
    let album: CGFloat

    init(total: CGFloat) {
        let gaps: CGFloat = 12 * 5
        let flexible = Swift.max(0, total - 44 - 56 - 40 - gaps - 16)
        title = flexible * 2.1 / 4.3
        artist = flexible * 1.1 / 4.3
        album = flexible * 1.1 / 4.3
    }
}

struct SongTableView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let songs = app.viewSongs
        let playbackSongs = app.viewPlaybackSongs
        let isSearching = !app.search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        GeometryReader { geo in
            let cols = ColumnWidths(total: geo.size.width - 32)
            if songs.isEmpty {
                EmptyHint(
                    text: app.search.isEmpty
                        ? emptyText
                        : "没有与「\(app.search)」匹配的结果"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    TableHeader(cols: cols)
                        .padding(.horizontal, 16)
                    NativeSongTableView(
                        songs: songs,
                        playbackSongs: playbackSongs,
                        isSearching: isSearching,
                        cols: cols
                    )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
    }

    private var emptyText: String {
        app.viewPlaylist == nil
            ? "资料库是空的，拖入音频文件或点击 + 导入"
            : "该分组暂无歌曲\n在歌曲上右键选择「添加到分组」"
    }
}

private struct NativeSongTableView: NSViewRepresentable {
    var songs: [Song]
    var playbackSongs: [Song]
    var isSearching: Bool
    var cols: ColumnWidths

    @Environment(AppState.self) private var app

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = SongTableScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = .zero
        tableView.rowHeight = 52
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.doubleClicked(_:))

        let column = NSTableColumn(identifier: Coordinator.columnIdentifier)
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        scrollView.tableView = tableView
        context.coordinator.tableView = tableView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(
            app: app,
            songs: songs,
            playbackSongs: playbackSongs,
            isSearching: isSearching,
            cols: cols
        )
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        static let columnIdentifier = NSUserInterfaceItemIdentifier("song-row")
        private let cellIdentifier = NSUserInterfaceItemIdentifier("song-row-cell")

        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?

        private var app: AppState?
        private var songs: [Song] = []
        private var playbackSongs: [Song] = []
        private var isSearching = false
        private var cols = ColumnWidths(total: 0)
        private var songIds: [String] = []
        private var lastColumnWidth: CGFloat = 0

        func update(
            app: AppState,
            songs: [Song],
            playbackSongs: [Song],
            isSearching: Bool,
            cols: ColumnWidths
        ) {
            self.app = app
            self.songs = songs
            self.playbackSongs = playbackSongs
            self.isSearching = isSearching
            self.cols = cols

            let ids = songs.map(\.id)
            let width = scrollView?.contentSize.width ?? 0
            if let tableView, let column = tableView.tableColumns.first, abs(column.width - width) > 0.5 {
                column.width = max(0, width)
                lastColumnWidth = column.width
            }

            if ids != songIds {
                songIds = ids
                tableView?.reloadData()
            } else if abs(lastColumnWidth - width) > 0.5 {
                refreshVisibleRows()
            } else {
                refreshVisibleRows()
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            songs.count
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            52
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard songs.indices.contains(row), let app else { return nil }
            let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? SongHostingCell
                ?? SongHostingCell(identifier: cellIdentifier)
            configure(cell, row: row, app: app)
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView, tableView.selectedRow >= 0, songs.indices.contains(tableView.selectedRow) else { return }
            app?.selectedId = songs[tableView.selectedRow].id
        }

        @objc func doubleClicked(_ sender: NSTableView) {
            let row = sender.clickedRow >= 0 ? sender.clickedRow : sender.selectedRow
            guard songs.indices.contains(row), let app else { return }
            play(song: songs[row], app: app)
        }

        private func refreshVisibleRows() {
            guard let tableView, let app else { return }
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            guard visibleRows.location != NSNotFound else { return }
            let end = min(visibleRows.location + visibleRows.length, songs.count)
            guard visibleRows.location < end else { return }

            for row in visibleRows.location..<end {
                if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? SongHostingCell {
                    configure(cell, row: row, app: app)
                }
            }
        }

        private func configure(_ cell: SongHostingCell, row: Int, app: AppState) {
            let song = songs[row]
            cell.set(
                AnyView(
                    SongRow(song: song, index: row, cols: cols) { [weak self, weak app] in
                        guard let self, let app else { return }
                        self.play(song: song, app: app)
                    }
                    .environment(app)
                )
            )
        }

        private func play(song: Song, app: AppState) {
            if isSearching {
                app.player.playSearchResult(song, fallbackContext: playbackSongs)
                return
            }
            let playbackIndex = playbackSongs.firstIndex { $0.id == song.id } ?? 0
            app.player.playFrom(playbackSongs, index: playbackIndex, rotateFromIndex: true)
        }
    }
}

private final class SongTableScrollView: NSScrollView {
    weak var tableView: NSTableView?

    override func layout() {
        super.layout()
        guard let column = tableView?.tableColumns.first else { return }
        column.width = max(0, contentSize.width)
    }
}

private final class SongHostingCell: NSTableCellView {
    private var hostingView: NSHostingView<AnyView>?

    convenience init(identifier: NSUserInterfaceItemIdentifier) {
        self.init(frame: .zero)
        self.identifier = identifier
    }

    func set(_ rootView: AnyView) {
        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            hostingView.setContentHuggingPriority(.defaultLow, for: .vertical)
            addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            self.hostingView = hostingView
        }
    }
}

private struct TableHeader: View {
    var cols: ColumnWidths
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 12) {
            Text("#").frame(width: 44)
            Text("标题").frame(width: cols.title, alignment: .leading)
            Text("艺术家").frame(width: cols.artist, alignment: .leading)
            Text("专辑").frame(width: cols.album, alignment: .leading)
            Text("时长").frame(width: 56, alignment: .trailing)
            Spacer().frame(width: 40)
        }
        .font(.system(size: 11.5, weight: .semibold))
        .kerning(0.35)
        .foregroundStyle(app.tokens.text3)
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(app.tokens.winBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(app.tokens.sep).frame(height: 1)
        }
    }
}

private struct SongRow: View {
    var song: Song
    var index: Int
    var cols: ColumnWidths
    var onPlay: () -> Void

    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    private var isCurrent: Bool { song.id == app.player.currentId }
    private var isSelected: Bool { song.id == app.selectedId }
    private var isMissing: Bool { app.missingIds.contains(song.id) }

    var body: some View {
        let album = song.albumId.flatMap { app.albumsById[$0] }
        HStack(spacing: 12) {
            // # / 均衡器 / hover 播放按钮
            ZStack {
                if isCurrent {
                    EqBars(paused: !app.player.isPlaying, accent: app.tokens.accent)
                        .transition(.opacity)
                } else if hovering {
                    Button(action: onPlay) {
                        Label("播放歌曲", systemImage: "play.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 11))
                            .foregroundStyle(app.tokens.text)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12.5))
                        .monospacedDigit()
                        .foregroundStyle(app.tokens.text3)
                        .transition(.opacity)
                }
            }
            .frame(width: 44)

            // 标题 + 封面
            HStack(spacing: 12) {
                CoverView(song: song, album: album, size: 36, radius: 6)
                Text(song.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(isCurrent ? app.tokens.accent : app.tokens.text)
                    .lineLimit(1)
                if isMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(app.tokens.text3)
                        .help("文件不可用，可重新定位或清理")
                }
                Spacer(minLength: 0)
            }
            .frame(width: cols.title, alignment: .leading)

            Text(app.artistName(for: song))
                .font(.system(size: 13.5))
                .foregroundStyle(app.tokens.text2)
                .lineLimit(1)
                .frame(width: cols.artist, alignment: .leading)

            Text(app.albumTitle(for: song))
                .font(.system(size: 13.5))
                .foregroundStyle(app.tokens.text2)
                .lineLimit(1)
                .frame(width: cols.album, alignment: .leading)

            Text(formatTime(song.duration))
                .font(.system(size: 12.5))
                .monospacedDigit()
                .foregroundStyle(app.tokens.text2)
                .frame(width: 56, alignment: .trailing)

            // 更多菜单：与整行右键菜单复用同一组动作
            Menu {
                SongContextMenu(song: song)
            } label: {
                Label("更多", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(app.tokens.text2)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("更多")
            .frame(width: 40)
            .opacity(hovering || isSelected ? 1 : 0.4)
            .animation(MotionTokens.feedback, value: hovering)
            .animation(MotionTokens.feedback, value: isSelected)
        }
        .opacity(isMissing ? 0.45 : 1)   // 失效曲目置灰（背景层在 .background 中保持原样）
        .padding(.horizontal, 8)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? app.tokens.selected : (hovering ? app.tokens.hover : .clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .gesture(TapGesture(count: 2).onEnded { onPlay() })
        .simultaneousGesture(TapGesture(count: 1).onEnded { app.selectedId = song.id })
        .contextMenu { SongContextMenu(song: song) }
        .animation(MotionTokens.feedback, value: hovering)
        .animation(MotionTokens.feedback, value: isSelected)
        .animation(MotionTokens.feedback, value: isCurrent)
    }
}

// MARK: - 右键菜单（player-views.jsx ContextMenu，动作后续接线）

private struct SongContextMenu: View {
    var song: Song
    @Environment(AppState.self) private var app

    private var addablePlaylists: [Playlist] {
        app.playlists.filter { playlist in
            !app.isSystemGroup(playlist)
                && app.viewPlaylist?.id != playlist.id
                && !playlist.songIds.contains(song.id)
        }
    }

    var body: some View {
        Button("立即播放") { app.player.playSongNow(song) }
        Button("下一首播放") { app.player.playNextSong(song) }
        Button("加入待播清单") { app.player.addToQueue(song) }
        Divider()
        if !addablePlaylists.isEmpty {
            Menu("添加到分组") {
                ForEach(addablePlaylists) { pl in
                    Button(pl.name) { app.addSong(song, to: pl) }
                }
            }
            Divider()
        }
        if app.missingIds.contains(song.id) {
            Button("重新定位…") { app.relocate(song) }
        }
        Button("在 Finder 中显示") { app.revealInFinder(song) }
        if song.fileURL != nil {
            Button("移到废纸篓并移除记录…", role: .destructive) { app.deleteLocalFile(for: song) }
        }
        if let playlist = app.viewPlaylist {
            Button("从此分组移除", role: .destructive) { app.removeSong(song, from: playlist) }
        } else {
            Button("仅从资料库移除", role: .destructive) { app.removeSong(song) }
        }
    }
}

// MARK: - 空状态（player.css .empty-hint）

struct EmptyHint: View {
    var text: String
    var small = false
    @Environment(AppState.self) private var app

    var body: some View {
        VStack {
            Text(text)
                .font(.system(size: small ? 12.5 : 13.5))
                .foregroundStyle(app.tokens.text3)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.vertical, small ? 28 : 60)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
    }
}
