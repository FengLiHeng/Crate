import SwiftUI

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
        GeometryReader { geo in
            let cols = ColumnWidths(total: geo.size.width - 32)
            if songs.isEmpty {
                EmptyHint(
                    text: app.search.isEmpty
                        ? emptyText
                        : "没有与「\(app.search)」匹配的结果"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(Array(songs.enumerated()), id: \.element.id) { i, song in
                                SongRow(song: song, index: i, cols: cols) {
                                    app.player.playFrom(songs, index: i)
                                }
                            }
                        } header: {
                            TableHeader(cols: cols)
                        }
                    }
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
                } else if hovering {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(app.tokens.text)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12.5))
                        .monospacedDigit()
                        .foregroundStyle(app.tokens.text3)
                }
            }
            .frame(width: 44)

            // 标题 + 封面
            HStack(spacing: 12) {
                CoverView(album: album, size: 36, radius: 6)
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

            // 更多按钮（hover/选中可见）
            IconButton(systemName: "ellipsis", size: 13, help: "更多") {
                app.selectedId = song.id
            }
            .frame(width: 40)
            .opacity(hovering || isSelected ? 1 : 0)
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
    }
}

// MARK: - 右键菜单（player-views.jsx ContextMenu，动作后续接线）

private struct SongContextMenu: View {
    var song: Song
    @Environment(AppState.self) private var app

    var body: some View {
        Button("立即播放") { app.player.playSongNow(song) }
        Button("下一首播放") { app.player.playNextSong(song) }
        Button("添加到待播清单") { app.player.addToQueue(song) }
        Divider()
        Menu("添加到分组") {
            if app.playlists.isEmpty {
                Button("暂无分组") {}
                    .disabled(true)
            } else {
                ForEach(app.playlists) { pl in
                    Button(pl.name) { app.addSong(song, to: pl) }
                }
            }
        }
        Divider()
        if app.missingIds.contains(song.id) {
            Button("重新定位…") { app.relocate(song) }
        }
        Button("在 Finder 中显示") { app.revealInFinder(song) }
        Button("从资料库中删除", role: .destructive) { app.removeSong(song) }
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
