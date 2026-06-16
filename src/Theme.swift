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
    let coverPaper: Color
    let coverPaperShade: Color
    let coverDisc: Color
    let coverGroove: Color
    let coverLabel: Color
    let coverCenter: Color
    let coverStroke: Color
    let coverSheen: Color

    static let light = ThemeTokens(
        winBg: oklch(0.988, 0.004, 145),
        sidebarBg: oklch(0.958, 0.007, 145),
        panelBg: oklch(0.968, 0.006, 145),
        playbarBg: oklch(0.972, 0.006, 145),
        menuBg: oklch(0.972, 0.006, 145, 0.92),
        text: oklch(0.22, 0.01, 160),
        text2: oklch(0.46, 0.012, 160),
        text3: oklch(0.61, 0.012, 160),
        sep: oklch(0.25, 0.014, 160, 0.1),
        hover: oklch(0.3, 0.018, 160, 0.055),
        selected: oklch(0.3, 0.024, 160, 0.095),
        ctrl: oklch(0.3, 0.018, 160, 0.065),
        accent: oklch(0.52, 0.095, 178),
        accentFg: .white,
        accentSoft: oklch(0.52, 0.095, 178, 0.13),
        thumb: .white,
        coverPaper: oklch(0.915, 0.012, 135),
        coverPaperShade: oklch(0.84, 0.018, 150, 0.72),
        coverDisc: oklch(0.29, 0.012, 210),
        coverGroove: oklch(0.92, 0.004, 120, 0.2),
        coverLabel: oklch(0.72, 0.04, 62),
        coverCenter: oklch(0.2, 0.01, 210),
        coverStroke: oklch(0.22, 0.018, 160, 0.16),
        coverSheen: .white.opacity(0.2)
    )

    static let dark = ThemeTokens(
        winBg: oklch(0.215, 0.008, 205),
        sidebarBg: oklch(0.25, 0.009, 205),
        panelBg: oklch(0.238, 0.009, 205),
        playbarBg: oklch(0.232, 0.009, 205),
        menuBg: oklch(0.29, 0.01, 205, 0.94),
        text: oklch(0.94, 0.004, 145),
        text2: oklch(0.72, 0.006, 145),
        text3: oklch(0.56, 0.006, 145),
        sep: oklch(0.95, 0.01, 145, 0.09),
        hover: oklch(0.9, 0.012, 145, 0.06),
        selected: oklch(0.9, 0.014, 145, 0.1),
        ctrl: oklch(0.9, 0.012, 145, 0.08),
        accent: oklch(0.71, 0.095, 178),
        accentFg: .white,
        accentSoft: oklch(0.71, 0.095, 178, 0.17),
        thumb: oklch(0.92, 0.004, 145),
        coverPaper: oklch(0.31, 0.012, 195),
        coverPaperShade: oklch(0.24, 0.014, 205, 0.78),
        coverDisc: oklch(0.16, 0.01, 220),
        coverGroove: oklch(0.9, 0.004, 145, 0.18),
        coverLabel: oklch(0.56, 0.04, 62),
        coverCenter: oklch(0.11, 0.008, 220),
        coverStroke: oklch(0.95, 0.006, 145, 0.13),
        coverSheen: .white.opacity(0.1)
    )

    static func of(_ theme: AppTheme) -> ThemeTokens {
        theme == .dark ? .dark : .light
    }
}

// MARK: - 封面占位与播放条氛围色

extension Album {
    func coverAccent(theme: AppTheme, alpha: Double = 1) -> Color {
        oklch(theme == .dark ? 0.66 : 0.55, theme == .dark ? 0.065 : 0.08, h1, alpha)
    }

    func coverAccentSoft(theme: AppTheme, alpha: Double = 1) -> Color {
        oklch(theme == .dark ? 0.56 : 0.78, theme == .dark ? 0.055 : 0.05, h2, alpha)
    }

    func playbarAmbient(theme: AppTheme, hue: Double, alpha: Double) -> Color {
        oklch(theme == .dark ? 0.58 : 0.68, theme == .dark ? 0.05 : 0.045, hue, alpha)
    }
}
