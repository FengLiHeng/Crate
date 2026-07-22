import SwiftUI
import AppKit

struct LyricsPlaybackView: View {
    var page: LyricsPageState

    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastScrolledLineId: Int?
    @State private var followsCurrentLine = true
    @State private var scrollMonitor: Any?
    @ScaledMetric(relativeTo: .title) private var songTitleSize: CGFloat = 25

    private let lyricsViewportTopPadding: CGFloat = 42

    private var song: Song? {
        app.songsById[page.songId] ?? app.player.currentSong
    }

    private var album: Album? {
        song?.albumId.flatMap { app.albumsById[$0] }
    }

    private var currentLineId: Int? {
        currentLineIndex.map { page.lyrics.lines[$0].id }
    }

    private var currentLineIndex: Int? {
        currentIndex(for: app.player.progress, in: page.lyrics.lines)
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                sidebar(width: min(360, max(260, geo.size.width * 0.34)))
                lyricsPane
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    app.tokens.winBg
                    if let album {
                        LinearGradient(
                            stops: [
                                .init(color: album.playbarAmbient(theme: app.theme, hue: album.h1, alpha: app.theme == .dark ? 0.22 : 0.09), location: 0),
                                .init(color: .clear, location: 0.48),
                                .init(color: album.playbarAmbient(theme: app.theme, hue: album.h2, alpha: app.theme == .dark ? 0.18 : 0.07), location: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .animation(MotionTokens.stateChange, value: album?.id)
            }
        }
    }

    private func sidebar(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Button {
                app.closeLyricsPage()
            } label: {
                Label("返回", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(app.tokens.text)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(app.tokens.ctrl))
            }
            .buttonStyle(.plain)
            .help("返回")

            Spacer(minLength: 0)

            if let song {
                CoverView(song: song, album: album, size: min(250, width - 72), radius: 0)
                    .padding(6)
                    .background(Rectangle().fill(app.tokens.menuBg))
                    .overlay {
                        Rectangle()
                            .strokeBorder(app.tokens.sep, lineWidth: 0.8)
                    }
                    .shadow(
                        color: .black.opacity(app.theme == .dark ? 0.24 : 0.09),
                        radius: 10,
                        y: 4
                    )
                    .scaleEffect(app.player.isPlaying && !reduceMotion ? 1.012 : 1)
                    .animation(MotionTokens.lyric(reduceMotion: reduceMotion), value: app.player.isPlaying)
                VStack(alignment: .leading, spacing: 7) {
                    Text(song.title)
                        .font(.system(size: songTitleSize, weight: .bold))
                        .foregroundStyle(app.tokens.text)
                        .lineLimit(3)
                    Text(app.artistName(for: song))
                        .font(.system(size: 14))
                        .foregroundStyle(app.tokens.text2)
                        .lineLimit(2)
                    Text(app.albumTitle(for: song))
                        .font(.system(size: 12.5))
                        .foregroundStyle(app.tokens.text3)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.init(top: 34, leading: 32, bottom: 34, trailing: 28))
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) {
            Rectangle().fill(app.tokens.sep).frame(width: 1)
        }
    }

    private var lyricsPane: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        Color.clear.frame(height: 120)
                        ForEach(Array(page.lyrics.lines.enumerated()), id: \.element.id) { index, line in
                            LyricLineView(line: line, active: index == currentLineIndex)
                                .id(line.id)
                        }
                        Color.clear.frame(height: 150)
                    }
                    .padding(.horizontal, 54)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, lyricsViewportTopPadding)

                if !followsCurrentLine {
                    Button {
                        followsCurrentLine = true
                        lastScrolledLineId = nil
                        scrollToCurrentLine(proxy: proxy, animated: true)
                    } label: {
                        Label("回到当前歌词", systemImage: "scope")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(24)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .onAppear {
                followsCurrentLine = true
                installScrollMonitor()
                scrollToCurrentLine(proxy: proxy, animated: false)
            }
            .onDisappear { removeScrollMonitor() }
            .onChange(of: page.songId) { _, _ in
                followsCurrentLine = true
                lastScrolledLineId = nil
                scrollToCurrentLine(proxy: proxy, animated: false)
            }
            .onChange(of: currentLineId) { _, _ in
                guard followsCurrentLine else { return }
                scrollToCurrentLine(proxy: proxy, animated: true)
            }
            .animation(MotionTokens.lyric(reduceMotion: reduceMotion), value: currentLineId)
            .animation(MotionTokens.feedback, value: followsCurrentLine)
        }
    }

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if abs(event.scrollingDeltaY) > 0.1 {
                followsCurrentLine = false
            }
            return event
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
        }
        scrollMonitor = nil
    }

    private func scrollToCurrentLine(proxy: ScrollViewProxy, animated: Bool) {
        guard let currentLineId, currentLineId != lastScrolledLineId else { return }
        lastScrolledLineId = currentLineId
        let action = {
            proxy.scrollTo(currentLineId, anchor: .center)
        }
        if animated {
            withAnimation(MotionTokens.lyric(reduceMotion: reduceMotion)) { action() }
        } else {
            action()
        }
    }

    private func currentIndex(for time: Double, in lines: [LyricLine]) -> Int? {
        guard !lines.isEmpty, time >= lines[0].time else { return nil }
        var low = 0
        var high = lines.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= time {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return max(0, high)
    }
}
