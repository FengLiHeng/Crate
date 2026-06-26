import SwiftUI

struct PlayBarView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                if let album {
                    LinearGradient(
                        stops: [
                            .init(color: album.playbarAmbient(theme: app.theme, hue: album.h1, alpha: app.theme == .dark ? 0.16 : 0.13), location: 0),
                            .init(color: .clear, location: 0.34),
                            .init(color: .clear, location: 0.66),
                            .init(color: album.playbarAmbient(theme: app.theme, hue: album.h2, alpha: app.theme == .dark ? 0.13 : 0.1), location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                }
            }
        }
        .animation(MotionTokens.stateChange, value: song?.id)
        .animation(MotionTokens.stateChange, value: album?.id)
        .overlay(alignment: .top) {
            Rectangle().fill(app.tokens.sep).frame(height: 1)
        }
    }

    // ── 左侧：当前曲目（player.css .pb-now） ──
    @ViewBuilder
    private func nowPlaying(song: Song?, album: Album?) -> some View {
        let songTransition: AnyTransition = reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom))

        HStack(spacing: 12) {
            if let song {
                LyricsCoverButton(song: song, album: album)
                    .id(song.id)
                    .transition(songTransition)
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
                .id(song.id)
                .transition(songTransition)
            } else {
                CoverView(size: 48, radius: 7)
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
                    systemName: playbackModeIcon(player), size: 14, side: 30,
                    active: playbackModeActive(player), help: playbackModeHelp(player)
                ) { player.cyclePlaybackMode() }

                IconButton(
                    systemName: "backward.fill", size: 17, side: 34,
                    disabled: song == nil, help: "上一首"
                ) { player.prev() }

                PlayButton(disabled: song == nil)

                IconButton(
                    systemName: "forward.fill", size: 17, side: 34,
                    disabled: song == nil, help: "下一首"
                ) { player.next() }

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

    private func playbackModeIcon(_ player: PlayerStore) -> String {
        if player.shuffle { return "shuffle" }
        if player.repeatMode == .one { return "repeat.1" }
        return "repeat"
    }

    private func playbackModeActive(_ player: PlayerStore) -> Bool {
        player.shuffle || player.repeatMode != .off
    }

    private func playbackModeHelp(_ player: PlayerStore) -> String {
        if player.shuffle { return "播放模式：随机播放" }
        switch player.repeatMode {
        case .off: return "播放模式：顺序播放"
        case .all: return "播放模式：列表循环"
        case .one: return "播放模式：单曲循环"
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
                withAnimation(MotionTokens.panel(reduceMotion: reduceMotion)) { app.toggleQueue() }
            }
        }
    }
}

private struct LyricsCoverButton: View {
    var song: Song
    var album: Album?

    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(MotionTokens.page(reduceMotion: reduceMotion)) {
                app.openLyricsForCurrentSong()
            }
        } label: {
            CoverView(song: song, album: album, size: 48, radius: 7)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(app.tokens.accentSoft)
                        .opacity(hovering ? 1 : 0)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(app.tokens.accentFg)
                        .frame(width: 17, height: 17)
                        .background(Circle().fill(app.tokens.accent))
                        .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
                        .opacity(hovering ? 1 : 0)
                        .offset(x: 3, y: 3)
                }
                .scaleEffect(pressed ? 0.95 : 1)
                .animation(MotionTokens.feedback, value: hovering)
                .animation(MotionTokens.press, value: pressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("打开歌词页")
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
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
            .animation(MotionTokens.feedback, value: isFavorite)
            .animation(MotionTokens.feedback, value: hovering)
            .animation(MotionTokens.press, value: pressed)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        let iconTransition: ContentTransition = reduceMotion ? .opacity : .symbolEffect(.replace)

        Button { app.player.togglePlay() } label: {
            Image(systemName: app.player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(app.tokens.accentFg)
                .frame(width: 40, height: 40)
                .background(Circle().fill(app.tokens.accent))
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                .brightness(hovering && !disabled ? 0.06 : 0)
                .scaleEffect(pressed ? 0.94 : 1)
                .contentTransition(iconTransition)
                .animation(MotionTokens.feedback, value: app.player.isPlaying)
                .animation(MotionTokens.feedback, value: hovering)
                .animation(MotionTokens.press, value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hovering = $0 }
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}
