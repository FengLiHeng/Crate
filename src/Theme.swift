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

func srgb(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) -> Color {
    Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: alpha)
}

// MARK: - 设计令牌

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
    let thumbStroke: Color
    let danger: Color
    let coverPaper: Color
    let coverPaperShade: Color
    let coverDisc: Color
    let coverGroove: Color
    let coverLabel: Color
    let coverCenter: Color
    let coverStroke: Color
    let coverSheen: Color

    static let light = ThemeTokens(
        winBg: srgb(246, 243, 237),
        sidebarBg: srgb(237, 231, 222),
        panelBg: srgb(241, 236, 229),
        playbarBg: srgb(239, 233, 224),
        menuBg: srgb(249, 246, 241, 0.94),
        text: srgb(37, 35, 33),
        text2: srgb(112, 105, 97),
        text3: srgb(139, 130, 120),
        sep: srgb(85, 74, 64, 0.16),
        hover: srgb(85, 74, 64, 0.07),
        selected: srgb(158, 47, 69, 0.12),
        ctrl: srgb(85, 74, 64, 0.085),
        accent: srgb(158, 47, 69),
        accentFg: .white,
        accentSoft: srgb(158, 47, 69, 0.13),
        thumb: .white,
        thumbStroke: srgb(37, 35, 33, 0.16),
        danger: srgb(173, 54, 54),
        coverPaper: srgb(226, 218, 204),
        coverPaperShade: srgb(200, 190, 174, 0.74),
        coverDisc: srgb(45, 45, 48),
        coverGroove: srgb(246, 243, 237, 0.22),
        coverLabel: srgb(190, 129, 78),
        coverCenter: srgb(29, 29, 31),
        coverStroke: srgb(37, 35, 33, 0.18),
        coverSheen: .white.opacity(0.22)
    )

    static let dark = ThemeTokens(
        winBg: srgb(14, 15, 16),
        sidebarBg: srgb(20, 21, 23),
        panelBg: srgb(24, 25, 27),
        playbarBg: srgb(18, 19, 20),
        menuBg: srgb(30, 31, 34, 0.96),
        text: srgb(235, 238, 236),
        text2: srgb(164, 172, 171),
        text3: srgb(116, 124, 124),
        sep: srgb(255, 255, 255, 0.09),
        hover: srgb(255, 255, 255, 0.07),
        selected: srgb(92, 197, 185, 0.16),
        ctrl: srgb(255, 255, 255, 0.075),
        accent: srgb(92, 197, 185),
        accentFg: srgb(5, 24, 24),
        accentSoft: srgb(92, 197, 185, 0.16),
        thumb: srgb(226, 231, 229),
        thumbStroke: srgb(255, 255, 255, 0.14),
        danger: srgb(231, 101, 94),
        coverPaper: srgb(38, 39, 40),
        coverPaperShade: srgb(24, 25, 26, 0.84),
        coverDisc: srgb(12, 13, 14),
        coverGroove: srgb(235, 238, 236, 0.14),
        coverLabel: srgb(82, 86, 86),
        coverCenter: srgb(15, 16, 17),
        coverStroke: srgb(255, 255, 255, 0.12),
        coverSheen: .white.opacity(0.08)
    )

    static func of(_ theme: AppTheme) -> ThemeTokens {
        theme == .dark ? .dark : .light
    }
}

// MARK: - 封面占位与播放条氛围色

extension Album {
    func coverAccent(theme: AppTheme, alpha: Double = 1) -> Color {
        oklch(theme == .dark ? 0.58 : 0.52, theme == .dark ? 0.04 : 0.068, h1, alpha)
    }

    func coverAccentSoft(theme: AppTheme, alpha: Double = 1) -> Color {
        oklch(theme == .dark ? 0.5 : 0.76, theme == .dark ? 0.03 : 0.042, h2, alpha)
    }

    func playbarAmbient(theme: AppTheme, hue: Double, alpha: Double) -> Color {
        oklch(theme == .dark ? 0.5 : 0.64, theme == .dark ? 0.03 : 0.036, hue, alpha)
    }
}
