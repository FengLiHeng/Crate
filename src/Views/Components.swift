import SwiftUI

// MARK: - 专辑封面（渐变占位 + 音符，player-ui.jsx Cover）

struct CoverView: View {
    var album: Album?
    var size: CGFloat = 36
    var radius: CGFloat = 6

    var body: some View {
        ZStack {
            if let album {
                Rectangle().fill(album.coverGradient)
            } else {
                Rectangle().fill(idleCoverGradient)
            }
            Image(systemName: "music.note")
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            // 左上高光（.cover::after）
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.2), location: 0),
                    .init(color: .clear, location: 0.45),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
    }
}

// MARK: - 歌单马赛克封面（最多 4 格，player-ui.jsx PlaylistCover）

struct PlaylistCoverView: View {
    var playlist: Playlist
    var albumsById: [String: Album]
    var songsById: [String: Song]
    var size: CGFloat = 36
    var radius: CGFloat = 6

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
                    Rectangle().fill(albs[0].coverGradient)
                    Rectangle().fill(albs[1].coverGradient)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(albs[2].coverGradient)
                    Rectangle().fill(albs[3].coverGradient)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
        }
    }
}

// MARK: - 正在播放均衡器动画（player.css .eq）

struct EqBars: View {
    var paused: Bool
    var accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = t / 0.9 - Double(i) * 0.28
                    let h = paused ? 5.0 : 4.0 + 10.0 * (0.5 - 0.5 * cos(phase * 2 * .pi))
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
    var value: Double
    var max: Double = 1
    var onChange: (Double) -> Void

    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            let pct = max > 0 ? min(Swift.max(value / max, 0), 1) : 0
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // 轨道
                Capsule().fill(app.tokens.ctrl).frame(height: 4)
                // 已填充
                Capsule().fill(app.tokens.accent)
                    .frame(width: Swift.max(4, pct * w), height: 4)
                // 滑块（hover 时出现）
                Circle()
                    .fill(app.tokens.thumb)
                    .frame(width: 11, height: 11)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .overlay(Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5))
                    .offset(x: pct * w - 5.5)
                    .scaleEffect(hovering ? 1 : 0.001)
                    .animation(.easeOut(duration: 0.12), value: hovering)
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let v = min(Swift.max(g.location.x / w, 0), 1) * max
                        onChange(v)
                    }
            )
        }
        .frame(height: 18)
        .onHover { hovering = $0 }
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
    var disabled: Bool = false
    var help: String = ""
    var action: () -> Void

    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(active ? app.tokens.accent : (hovering ? app.tokens.text : app.tokens.text2))
                .frame(width: side, height: side)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(active ? app.tokens.accentSoft : (hovering ? app.tokens.hover : .clear))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hovering = $0 }
        .help(help)
    }
}
