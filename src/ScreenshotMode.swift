import AppKit
import Foundation

enum ScreenshotScene: String, CaseIterable {
    case lightHome = "light-home"
    case darkHome = "dark-home"
    case lightQueue = "light-queue"
    case lightLyrics = "light-lyrics"

    var theme: AppTheme {
        self == .darkHome ? .dark : .light
    }
}

struct ScreenshotLaunchConfiguration: Equatable {
    var scene: ScreenshotScene
    var readyFileURL: URL
    var storeDirectoryURL: URL

    static func parse(arguments: [String]) -> ScreenshotLaunchConfiguration? {
        guard let sceneValue = value(after: "--screenshot-scene", in: arguments),
              let scene = ScreenshotScene(rawValue: sceneValue),
              let readyPath = value(after: "--screenshot-ready-file", in: arguments),
              let storePath = value(after: "--screenshot-store", in: arguments) else { return nil }

        return ScreenshotLaunchConfiguration(
            scene: scene,
            readyFileURL: URL(fileURLWithPath: readyPath),
            storeDirectoryURL: URL(fileURLWithPath: storePath, isDirectory: true)
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

@MainActor
enum ScreenshotFixture {
    static let albums: [Album] = SampleData.albums.enumerated().map { index, album in
        var album = album
        album.artworkData = artworkData(for: album, index: index)
        return album
    }

    static let songs = SampleData.songs

    static let playlists: [Playlist] = [
        Playlist(
            id: AppState.favoritesGroupId,
            name: AppState.favoritesGroupName,
            songIds: ["s01", "s05", "s09", "s15", "s23"]
        )
    ] + SampleData.playlists

    static let lyrics: ParsedLyrics = {
        try! LRCParser.parse("""
        [00:00.00]夜色落在旧唱片的纹路
        [00:08.00]针尖轻触沉睡已久的温度
        [00:16.00]城市的灯沿着河面慢慢漂浮
        [00:24.00]我们把未说完的话留给旅途
        [00:32.00]风穿过窗边翻动泛黄的曲谱
        [00:40.00]熟悉旋律让时间停住脚步
        [00:48.00]此刻所有喧嚣都安静落幕
        [00:56.00]只剩一首歌陪我走向日出
        [01:04.00]收藏每一次偶然相遇的幸福
        [01:12.00]让回忆在下一段前奏里复苏
        """)
    }()

    static func configurePlayback(in app: AppState, for scene: ScreenshotScene) {
        let currentIndex = scene == .lightLyrics ? 14 : 4
        let current = songs[currentIndex]
        let ids = songs.map(\.id)

        app.player.currentId = current.id
        app.player.progress = scene == .lightLyrics ? 51 : 74
        app.player.isPlaying = true
        app.player.shuffle = false
        app.player.repeatMode = .all
        app.player.ctx = PlayerStore.Context(ids: ids, originalIds: ids, pos: currentIndex)
        app.player.manualQueue = ["s23", "s12"]
        app.selectedId = songs[7].id

        if scene == .lightQueue {
            app.openQueue()
        } else if scene == .lightLyrics {
            app.lyricsPage = LyricsPageState(
                songId: current.id,
                lyricsURL: URL(fileURLWithPath: "/screenshot/电台午夜.lrc"),
                lyrics: lyrics
            )
        }
    }

    private static func artworkData(for album: Album, index: Int) -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 512,
            pixelsHigh: 512,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }

        let size = NSSize(width: 512, height: 512)

        let hue = CGFloat(album.h1 / 360)
        let secondHue = CGFloat(album.h2 / 360)
        let start = NSColor(calibratedHue: hue, saturation: 0.56, brightness: 0.62, alpha: 1)
        let end = NSColor(calibratedHue: secondHue, saturation: 0.46, brightness: 0.28, alpha: 1)
        NSGradient(starting: start, ending: end)?.draw(in: NSRect(origin: .zero, size: size), angle: -35)

        NSColor.white.withAlphaComponent(0.12).setFill()
        let circle = NSBezierPath(
            ovalIn: NSRect(x: CGFloat(86 + index * 4), y: 110, width: 340, height: 340)
        )
        circle.fill()

        NSColor.black.withAlphaComponent(0.16).setStroke()
        for inset in stride(from: CGFloat(110), through: CGFloat(185), by: CGFloat(15)) {
            let groove = NSBezierPath(ovalIn: NSRect(x: inset, y: inset, width: 512 - inset * 2, height: 512 - inset * 2))
            groove.lineWidth = 2
            groove.stroke()
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let title = NSString(string: album.title)
        title.draw(
            in: NSRect(x: 42, y: 34, width: 428, height: 82),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 36, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.92),
                .paragraphStyle: paragraph,
            ]
        )

        context.flushGraphics()
        return bitmap.representation(using: .png, properties: [:])
    }
}

@MainActor
enum ScreenshotWindowCoordinator {
    static func prepare(configuration: ScreenshotLaunchConfiguration?) {
        guard let configuration else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
            window.setContentSize(NSSize(width: 1240, height: 760))
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let value = "\(window.windowNumber)\n"
                try? value.write(to: configuration.readyFileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
