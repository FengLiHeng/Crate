import SwiftUI

struct LyricLineView: View {
    var line: LyricLine
    var active: Bool

    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @ScaledMetric(relativeTo: .title) private var activeFontSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title3) private var normalFontSize: CGFloat = 19
    @ScaledMetric(relativeTo: .caption) private var timestampFontSize: CGFloat = 11

    private var timeLabel: String {
        formatTime(line.time)
    }

    var body: some View {
        Button {
            app.player.seek(to: line.time)
        } label: {
            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(size: active ? activeFontSize : normalFontSize, weight: active ? .bold : .medium))
                .foregroundStyle(active ? app.tokens.text : app.tokens.text3)
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, active ? 11 : 8)
                .padding(.leading, active && !reduceMotion ? 8 : 0)
                .padding(.trailing, 66)
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(app.tokens.accent)
                        .frame(width: 3, height: active ? 28 : 0)
                        .opacity(active ? 0.85 : 0)
                        .offset(x: -14)
                }
                .overlay(alignment: .trailing) {
                    Text(timeLabel)
                        .font(.system(size: timestampFontSize, weight: .semibold, design: .monospaced))
                        .foregroundStyle(app.tokens.accentFg)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background {
                            Capsule(style: .continuous)
                                .fill(app.tokens.accent)
                        }
                        .shadow(
                            color: .black.opacity(app.theme == .dark ? 0.28 : 0.12),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                        .opacity(hovering ? 1 : 0)
                        .scaleEffect(hovering && !reduceMotion ? 1 : 0.98, anchor: .trailing)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityHint("跳转到 \(timeLabel)")
        .animation(MotionTokens.feedback, value: hovering)
        .animation(MotionTokens.lyric(reduceMotion: reduceMotion), value: active)
    }
}
