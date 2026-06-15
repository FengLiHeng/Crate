import SwiftUI

struct PlayBarView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let song = app.player.currentSong
        let album = song?.albumId.flatMap { app.albumsById[$0] }

        HStack(spacing: 16) {
            nowPlaying(song: song, album: album)
                .frame(maxWidth: .infinity, alignment: .leading)

            centerControls(song: song)
                .frame(minWidth: 360, maxWidth: 560)

            rightControls
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 84)
        .background {
            ZStack {
                app.tokens.playbarBg
                // 专辑氛围渐变（player.css .pb-ambient）
                if let album {
                    LinearGradient(
                        stops: [
                            .init(color: oklch(0.65, 0.1, album.h1, 0.2), location: 0),
                            .init(color: .clear, location: 0.4),
                            .init(color: .clear, location: 0.6),
                            .init(color: oklch(0.65, 0.1, album.h2, 0.16), location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                }
            }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(app.tokens.sep).frame(height: 1)
        }
    }

    // ── 左侧：当前曲目（player.css .pb-now） ──
    @ViewBuilder
    private func nowPlaying(song: Song?, album: Album?) -> some View {
        HStack(spacing: 12) {
            if let song {
                CoverView(song: song, album: album, size: 48, radius: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(app.tokens.text)
                        .lineLimit(1)
                    Text(app.artistName(for: song))
                        .font(.system(size: 12))
                        .foregroundStyle(app.tokens.text2)
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(app.tokens.ctrl)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 17))
                            .foregroundStyle(app.tokens.text3)
                    )
                Text("未在播放")
                    .font(.system(size: 12))
                    .foregroundStyle(app.tokens.text2)
            }
        }
    }

    // ── 中部：控制组 + 进度（player.css .pb-center） ──
    private func centerControls(song: Song?) -> some View {
        let player = app.player
        return VStack(spacing: 4) {
            HStack(spacing: 14) {
                IconButton(
                    systemName: "shuffle", size: 14, side: 30,
                    active: player.shuffle, help: "随机播放"
                ) { player.toggleShuffle() }

                IconButton(
                    systemName: "backward.fill", size: 17, side: 34,
                    disabled: song == nil, help: "上一首"
                ) { player.prev() }

                PlayButton(disabled: song == nil)

                IconButton(
                    systemName: "forward.fill", size: 17, side: 34,
                    disabled: song == nil, help: "下一首"
                ) { player.next() }

                IconButton(
                    systemName: player.repeatMode == .one ? "repeat.1" : "repeat",
                    size: 14, side: 30,
                    active: player.repeatMode != .off,
                    help: player.repeatMode == .off ? "循环播放：关" : player.repeatMode == .all ? "列表循环" : "单曲循环"
                ) { player.cycleRepeat() }

                FavoriteButton(song: song)
            }

            HStack(spacing: 10) {
                Text(song != nil ? formatTime(player.progress) : "-:--")
                    .frame(width: 40, alignment: .leading)
                UISlider(value: song != nil ? player.progress : 0, max: song?.duration ?? 1) { v in
                    if song != nil { player.seek(to: v) }
                }
                Text(song != nil ? "-" + formatTime((song?.duration ?? 0) - player.progress) : "-:--")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(app.tokens.text3)
        }
    }

    // ── 右侧：音量 + 队列（player.css .pb-right） ──
    private var rightControls: some View {
        HStack(spacing: 10) {
            Image(systemName: app.player.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13))
                .foregroundStyle(app.tokens.text2)
            UISlider(value: app.player.volume, max: 1) { app.player.volume = $0 }
                .frame(width: 90)
            IconButton(
                systemName: "list.triangle", size: 15, side: 30,
                active: app.queueOpen, help: "待播清单"
            ) {
                withAnimation(.spring(duration: 0.28)) { app.queueOpen.toggle() }
            }
        }
    }
}

private struct FavoriteButton: View {
    var song: Song?

    @Environment(AppState.self) private var app
    @State private var hovering = false
    @State private var pressed = false

    private var isFavorite: Bool {
        song.map(app.isFavorite) ?? false
    }

    var body: some View {
        Button {
            guard let song else { return }
            app.toggleFavorite(song)
        } label: {
            ZStack {
                Image(systemName: "heart")
                    .opacity(isFavorite ? 0 : 1)
                Image(systemName: "heart.fill")
                    .opacity(isFavorite ? 1 : 0)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(isFavorite ? app.tokens.accent : (hovering ? app.tokens.text : app.tokens.text2))
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isFavorite ? app.tokens.accentSoft : (hovering ? app.tokens.hover : .clear))
            )
            .scaleEffect(pressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: isFavorite)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.08), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(song == nil)
        .opacity(song == nil ? 0.35 : 1)
        .onHover { hovering = $0 }
        .help(isFavorite ? "取消收藏" : "收藏")
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}

// 主播放按钮（player.css .pb-play）
private struct PlayButton: View {
    var disabled: Bool

    @Environment(AppState.self) private var app
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button { app.player.togglePlay() } label: {
            Image(systemName: app.player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(app.tokens.accentFg)
                .frame(width: 40, height: 40)
                .background(Circle().fill(app.tokens.accent))
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                .brightness(hovering && !disabled ? 0.06 : 0)
                .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hovering = $0 }
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}

// 按压缩放辅助
private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}
