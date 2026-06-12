import SwiftUI

// 待播清单面板（player.css .queue-panel / player-views.jsx QueuePanel）
struct QueuePanelView: View {
    @Environment(AppState.self) private var app

    private var manualSongs: [Song] {
        let byId = app.songsById
        return app.player.manualQueue.compactMap { byId[$0] }
    }

    private var upcomingSongs: [Song] {
        let byId = app.songsById
        return app.player.upcomingIds.compactMap { byId[$0] }
    }

    var body: some View {
        let hasUpcoming = !manualSongs.isEmpty || !upcomingSongs.isEmpty

        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("待播清单")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(app.tokens.text)
                Spacer()
                if hasUpcoming {
                    Button("清空") { app.player.clearQueue() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(app.tokens.accent)
                }
                IconButton(systemName: "xmark", size: 11, side: 24, help: "关闭") {
                    withAnimation(.spring(duration: 0.28)) { app.queueOpen = false }
                }
            }
            .padding(.init(top: 16, leading: 18, bottom: 10, trailing: 14))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let current = app.player.currentSong {
                        sectionLabel("正在播放")
                        QueueRow(song: current, isCurrent: true)

                        if !manualSongs.isEmpty {
                            sectionLabel("插播 · 下一首播放")
                            ForEach(Array(manualSongs.enumerated()), id: \.offset) { i, s in
                                QueueRow(
                                    song: s, isCurrent: false, removable: true,
                                    onPlay: { app.player.playManualAt(i) },
                                    onRemove: { app.player.removeManualAt(i) }
                                )
                            }
                        }
                        if !upcomingSongs.isEmpty {
                            sectionLabel("接下来")
                            ForEach(Array(upcomingSongs.enumerated()), id: \.offset) { i, s in
                                QueueRow(
                                    song: s, isCurrent: false,
                                    onPlay: { app.player.playContextAt(i) }
                                )
                            }
                        }
                        if !hasUpcoming {
                            EmptyHint(text: "队列中暂无后续歌曲\n在歌曲上右键选择「下一首播放」试试", small: true)
                        }
                    } else {
                        EmptyHint(text: "当前没有播放内容")
                    }
                }
                .padding(.init(top: 0, leading: 10, bottom: 16, trailing: 10))
            }
        }
        .frame(width: 300)
        .background(app.tokens.panelBg)
        .overlay(alignment: .leading) {
            Rectangle().fill(app.tokens.sep).frame(width: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 16, x: -6)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(app.tokens.text3)
            .padding(.init(top: 14, leading: 8, bottom: 6, trailing: 8))
    }
}

private struct QueueRow: View {
    var song: Song
    var isCurrent: Bool
    var removable = false
    var onPlay: (() -> Void)?
    var onRemove: (() -> Void)?

    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        let album = song.albumId.flatMap { app.albumsById[$0] }
        HStack(spacing: 10) {
            CoverView(album: album, size: 34, radius: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCurrent ? app.tokens.accent : app.tokens.text)
                    .lineLimit(1)
                Text(app.artistName(for: song))
                    .font(.system(size: 11.5))
                    .foregroundStyle(app.tokens.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isCurrent {
                EqBars(paused: !app.player.isPlaying, accent: app.tokens.accent)
            } else if removable && hovering {
                IconButton(systemName: "xmark", size: 10, side: 22, help: "从队列移除") {
                    onRemove?()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering && !isCurrent ? app.tokens.hover : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .gesture(TapGesture(count: 2).onEnded { onPlay?() })
    }
}
