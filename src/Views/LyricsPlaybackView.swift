import SwiftUI

struct LyricsPlaybackView: View {
    var page: LyricsPageState

    @Environment(AppState.self) private var app
    @State private var lastScrolledLineId: Int?

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
                                .init(color: album.playbarAmbient(theme: app.theme, hue: album.h1, alpha: app.theme == .dark ? 0.22 : 0.16), location: 0),
                                .init(color: .clear, location: 0.48),
                                .init(color: album.playbarAmbient(theme: app.theme, hue: album.h2, alpha: app.theme == .dark ? 0.18 : 0.13), location: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
        }
    }

    private func sidebar(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Button {
                app.closeLyricsPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(app.tokens.text)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(app.tokens.ctrl))
            }
            .buttonStyle(.plain)
            .help("返回")

            Spacer(minLength: 0)

            if let song {
                CoverView(song: song, album: album, size: min(250, width - 72), radius: 16)
                VStack(alignment: .leading, spacing: 7) {
                    Text(song.title)
                        .font(.system(size: 25, weight: .bold))
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Color.clear.frame(height: 120)
                    ForEach(Array(page.lyrics.lines.enumerated()), id: \.element.id) { index, line in
                        lyricLine(line, active: index == currentLineIndex)
                            .id(line.id)
                    }
                    Color.clear.frame(height: 150)
                }
                .padding(.horizontal, 54)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                scrollToCurrentLine(proxy: proxy, animated: false)
            }
            .onChange(of: currentLineId) { _, _ in
                scrollToCurrentLine(proxy: proxy, animated: true)
            }
        }
    }

    private func lyricLine(_ line: LyricLine, active: Bool) -> some View {
        Button {
            app.player.seek(to: line.time)
        } label: {
            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(size: active ? 28 : 19, weight: active ? .bold : .semibold))
                .foregroundStyle(active ? app.tokens.text : app.tokens.text2)
                .opacity(active ? 1 : 0.52)
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, active ? 11 : 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(formatTime(line.time))
        .animation(.easeOut(duration: 0.18), value: active)
    }

    private func scrollToCurrentLine(proxy: ScrollViewProxy, animated: Bool) {
        guard let currentLineId, currentLineId != lastScrolledLineId else { return }
        lastScrolledLineId = currentLineId
        let action = {
            proxy.scrollTo(currentLineId, anchor: .center)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.32)) { action() }
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
