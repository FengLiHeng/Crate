import SwiftUI
import AppKit

@MainActor
final class MouseDragReleaseMonitor {
    private var timer: Timer?

    func start(onRelease: @escaping @MainActor @Sendable () -> Void) {
        stop()
        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in
            guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
            Task { @MainActor in
                onRelease()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
private final class ArtworkImageCache {
    static let shared = ArtworkImageCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 600
    }

    func image(for data: Data?, key: String) -> NSImage? {
        guard let data else { return nil }
        let cacheKey = NSString(string: "\(key)-\(data.count)")
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: cacheKey)
        return image
    }
}

@MainActor
private enum AlbumPlaceholderImage {
    static let image: NSImage? = {
        if let image = NSImage(named: NSImage.Name("AlbumPlaceholder")) {
            return image
        }

        let executableDir = Bundle.main.executableURL?.deletingLastPathComponent()
        let resourceDir = Bundle.main.resourceURL
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "album-placeholder", withExtension: "png"),
            resourceDir?.appendingPathComponent("Assets.xcassets/AlbumPlaceholder.imageset/album-placeholder.png"),
            resourceDir?.appendingPathComponent("Crate_Crate.bundle/Assets.xcassets/AlbumPlaceholder.imageset/album-placeholder.png"),
            executableDir?.appendingPathComponent("Crate_Crate.bundle/Assets.xcassets/AlbumPlaceholder.imageset/album-placeholder.png"),
        ]

        for url in candidates {
            guard let url, let image = NSImage(contentsOf: url) else { continue }
            return image
        }
        return nil
    }()
}

// MARK: - 专辑封面（真实封面 + 统一占位符）

struct CoverView: View {
    var song: Song? = nil
    var album: Album? = nil
    var size: CGFloat = 36
    var radius: CGFloat = 6

    @Environment(AppState.self) private var app

    private var artworkImage: NSImage? {
        if let song,
           let image = ArtworkImageCache.shared.image(for: song.artworkData, key: "song-\(song.id)") {
            return image
        }
        if let album,
           let image = ArtworkImageCache.shared.image(for: album.artworkData, key: "album-\(album.id)") {
            return image
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .scaledToFill()
            } else {
                CoverPlaceholderView()
            }
            LinearGradient(
                stops: [
                    .init(color: app.tokens.coverSheen, location: 0),
                    .init(color: .clear, location: 0.42),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(app.tokens.coverStroke, lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(app.theme == .dark ? 0.28 : 0.14), radius: 1.6, y: 1)
    }
}

private struct CoverPlaceholderView: View {
    var body: some View {
        if let image = AlbumPlaceholderImage.image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            CoverPlaceholderFallbackView()
        }
    }
}

private struct CoverPlaceholderFallbackView: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(
                    colors: [srgb(42, 43, 44), srgb(20, 21, 22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(srgb(22, 23, 24))
                    .frame(width: side * 0.74, height: side * 0.74)

                Circle()
                    .stroke(srgb(255, 255, 255, 0.08), lineWidth: max(0.5, side * 0.012))
                    .frame(width: side * 0.58, height: side * 0.58)

                Circle()
                    .fill(srgb(50, 51, 52))
                    .frame(width: side * 0.32, height: side * 0.32)
            }
        }
    }
}

// MARK: - 分组马赛克封面（最多 4 格，player-ui.jsx PlaylistCover）

struct PlaylistCoverView: View {
    var playlist: Playlist
    var albumsById: [String: Album]
    var songsById: [String: Song]
    var size: CGFloat = 36
    var radius: CGFloat = 6

    @Environment(AppState.self) private var app

    private var mosaicAlbums: [Album] {
        var result: [Album] = []
        for sid in playlist.songIds {
            guard let s = songsById[sid], let aid = s.albumId, let a = albumsById[aid] else { continue }
            if !result.contains(where: { $0.id == a.id }) { result.append(a) }
            if result.count == 4 { break }
        }
        return result
    }

    var body: some View {
        let albs = mosaicAlbums
        if albs.count < 4 {
            CoverView(album: albs.first, size: size, radius: radius)
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    AlbumCoverTile(album: albs[0])
                    AlbumCoverTile(album: albs[1])
                }
                HStack(spacing: 0) {
                    AlbumCoverTile(album: albs[2])
                    AlbumCoverTile(album: albs[3])
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(app.tokens.coverStroke, lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(app.theme == .dark ? 0.28 : 0.14), radius: 1.6, y: 1)
        }
    }
}

private struct AlbumCoverTile: View {
    var album: Album

    @Environment(AppState.self) private var app

    private var artworkImage: NSImage? {
        ArtworkImageCache.shared.image(for: album.artworkData, key: "album-\(album.id)")
    }

    var body: some View {
        ZStack {
            if let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .scaledToFill()
            } else {
                CoverPlaceholderView()
            }
            LinearGradient(
                stops: [
                    .init(color: app.tokens.coverSheen, location: 0),
                    .init(color: .clear, location: 0.42),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .clipped()
    }
}

// MARK: - 正在播放均衡器动画（player.css .eq）

struct EqBars: View {
    var paused: Bool
    var accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused || reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = t / 0.9 - Double(i) * 0.28
                    let h = (paused || reduceMotion) ? 5.0 : 4.0 + 10.0 * (0.5 - 0.5 * cos(phase * 2 * .pi))
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: 3, height: h)
                }
            }
            .frame(height: 14, alignment: .bottom)
        }
        .frame(width: 13, height: 14)
    }
}

// MARK: - 自绘滑杆（进度/音量，player-ui.jsx Slider + player.css .slider）

struct UISlider: View {
    var label: String = "滑杆"
    var value: Double
    var max: Double = 1
    var accessibilityValueText: String?
    var onChange: (Double) -> Void

    @Environment(AppState.self) private var app
    @State private var hovering = false

    private var clampedMax: Double {
        Swift.max(max, 0)
    }

    private var clampedValue: Double {
        guard clampedMax > 0 else { return 0 }
        return min(Swift.max(value, 0), clampedMax)
    }

    private var percent: Double {
        guard clampedMax > 0 else { return 0 }
        return clampedValue / clampedMax
    }

    private var accessibilityValue: String {
        "\(Int((percent * 100).rounded()))%"
    }

    var body: some View {
        GeometryReader { geo in
            let pct = percent
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // 轨道
                Capsule().fill(app.tokens.ctrl).frame(height: 4)
                // 已填充
                Capsule().fill(app.tokens.accent)
                    .frame(width: pct > 0 ? Swift.max(4, pct * w) : 0, height: 4)
                    .animation(MotionTokens.progress, value: pct)
                // 滑块（hover 时出现）
                Circle()
                    .fill(app.tokens.thumb)
                    .frame(width: 11, height: 11)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .overlay(Circle().strokeBorder(app.tokens.thumbStroke, lineWidth: 0.5))
                    .offset(x: pct * w - 5.5)
                    .opacity(hovering ? 1 : 0)
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        guard w > 0 else { return }
                        let v = min(Swift.max(g.location.x / w, 0), 1) * clampedMax
                        onChange(v)
                    }
            )
        }
        .frame(height: 18)
        .onHover { hovering = $0 }
        .accessibilityElement()
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(accessibilityValueText ?? accessibilityValue))
        .accessibilityAdjustableAction { direction in
            adjustAccessibilityValue(direction)
        }
    }

    private func adjustAccessibilityValue(_ direction: AccessibilityAdjustmentDirection) {
        guard clampedMax > 0 else { return }
        let step = Swift.max(clampedMax / 20, 0.05)
        switch direction {
        case .increment:
            onChange(min(clampedValue + step, clampedMax))
        case .decrement:
            onChange(Swift.max(clampedValue - step, 0))
        @unknown default:
            break
        }
    }
}

// MARK: - Toast（player.css .toast）

struct ToastView: View {
    var message: String

    @Environment(AppState.self) private var app

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(app.tokens.text)
            .lineLimit(1)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
            .background(app.tokens.menuBg, in: Capsule())
            .overlay(Capsule().strokeBorder(app.tokens.sep, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 3)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - 图标按钮（player.css .icon-btn）

struct IconButton: View {
    var systemName: String
    var size: CGFloat = 16
    var side: CGFloat = 28
    var active: Bool = false
    var showsActiveBackground: Bool = true
    var disabled: Bool = false
    var help: String = ""
    var action: () -> Void

    @Environment(AppState.self) private var app
    @State private var hovering = false
    @State private var pressed = false

    private var accessibilityTitle: String {
        help.isEmpty ? systemName : help
    }

    var body: some View {
        Button(action: action) {
            Label(accessibilityTitle, systemImage: systemName)
                .labelStyle(.iconOnly)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(active ? app.tokens.accent : (hovering ? app.tokens.text : app.tokens.text2))
                .frame(width: side, height: side)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(active && showsActiveBackground ? app.tokens.accentSoft : (hovering ? app.tokens.hover : .clear))
                )
                .scaleEffect(pressed ? 0.94 : 1)
                .animation(MotionTokens.feedback, value: hovering)
                .animation(MotionTokens.feedback, value: active)
                .animation(MotionTokens.press, value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hovering = $0 }
        .help(help)
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}
