import SwiftUI

// MARK: - OKLCH → sRGB

/// 运行时把 tokens.css 中的 OKLCH 颜色精确换算为 sRGB，
/// 避免手工预换算引入色差（design.md D5）。
func oklch(_ L: Double, _ C: Double, _ h: Double, _ alpha: Double = 1) -> Color {
    let hr = h * .pi / 180
    let a = C * cos(hr)
    let b = C * sin(hr)

    // OKLab → LMS（立方根空间）
    let l_ = L + 0.3963377774 * a + 0.2158037573 * b
    let m_ = L - 0.1055613458 * a - 0.0638541728 * b
    let s_ = L - 0.0894841775 * a - 1.2914855480 * b
    let l = l_ * l_ * l_
    let m = m_ * m_ * m_
    let s = s_ * s_ * s_

    // LMS → 线性 sRGB
    var r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    var g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    var bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    func gamma(_ c: Double) -> Double {
        let c = min(max(c, 0), 1)
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
    r = gamma(r); g = gamma(g); bl = gamma(bl)
    return Color(.sRGB, red: r, green: g, blue: bl, opacity: alpha)
}

// MARK: - 设计令牌（tokens.css 的 Swift 映射）

enum AppTheme: String {
    case light, dark
}

struct ThemeTokens {
    let winBg: Color
    let sidebarBg: Color
    let panelBg: Color
    let playbarBg: Color
    let menuBg: Color
    let text: Color
    let text2: Color
    let text3: Color
    let sep: Color
    let hover: Color
    let selected: Color
    let ctrl: Color
    let accent: Color
    let accentFg: Color
    let accentSoft: Color
    let thumb: Color

    static let light = ThemeTokens(
        winBg: oklch(0.99, 0.002, 80),
        sidebarBg: oklch(0.966, 0.004, 80),
        panelBg: oklch(0.975, 0.003, 80),
        playbarBg: oklch(0.978, 0.003, 80),
        menuBg: oklch(0.975, 0.003, 80, 0.92),
        text: oklch(0.21, 0.005, 80),
        text2: oklch(0.47, 0.008, 80),
        text3: oklch(0.62, 0.008, 80),
        sep: oklch(0.25, 0.01, 80, 0.1),
        hover: oklch(0.3, 0.01, 80, 0.05),
        selected: oklch(0.3, 0.02, 80, 0.09),
        ctrl: oklch(0.3, 0.01, 80, 0.06),
        accent: oklch(0.6, 0.19, 30),
        accentFg: .white,
        accentSoft: oklch(0.6, 0.19, 30, 0.11),
        thumb: .white
    )

    static let dark = ThemeTokens(
        winBg: oklch(0.215, 0.005, 270),
        sidebarBg: oklch(0.25, 0.006, 270),
        panelBg: oklch(0.24, 0.006, 270),
        playbarBg: oklch(0.235, 0.006, 270),
        menuBg: oklch(0.29, 0.007, 270, 0.94),
        text: oklch(0.94, 0.003, 80),
        text2: oklch(0.72, 0.005, 80),
        text3: oklch(0.56, 0.005, 80),
        sep: oklch(0.95, 0.01, 80, 0.09),
        hover: oklch(0.9, 0.01, 80, 0.06),
        selected: oklch(0.9, 0.01, 80, 0.1),
        ctrl: oklch(0.9, 0.01, 80, 0.08),
        accent: oklch(0.67, 0.18, 30),
        accentFg: .white,
        accentSoft: oklch(0.67, 0.18, 30, 0.16),
        thumb: oklch(0.92, 0.003, 80)
    )

    static func of(_ theme: AppTheme) -> ThemeTokens {
        theme == .dark ? .dark : .light
    }
}

// MARK: - 封面渐变（player-ui.jsx Cover 的等价实现）

extension Album {
    var coverGradient: LinearGradient {
        LinearGradient(
            colors: [oklch(0.7, 0.14, h1), oklch(0.4, 0.13, h2)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

/// 无专辑时的灰色封面渐变
let idleCoverGradient = LinearGradient(
    colors: [oklch(0.55, 0.006, 80), oklch(0.36, 0.006, 80)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)
