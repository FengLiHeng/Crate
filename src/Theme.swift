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
        winBg: srgb(17, 19, 21),
        sidebarBg: srgb(26, 29, 32),
        panelBg: srgb(30, 33, 36),
        playbarBg: srgb(24, 26, 29),
        menuBg: srgb(35, 38, 42, 0.95),
        text: srgb(242, 240, 234),
        text2: srgb(171, 166, 155),
        text3: srgb(126, 124, 117),
        sep: srgb(242, 240, 234, 0.1),
        hover: srgb(242, 240, 234, 0.065),
        selected: srgb(196, 122, 58, 0.16),
        ctrl: srgb(242, 240, 234, 0.085),
        accent: srgb(196, 122, 58),
        accentFg: srgb(22, 18, 15),
        accentSoft: srgb(196, 122, 58, 0.18),
        thumb: srgb(232, 225, 214),
        thumbStroke: srgb(255, 255, 255, 0.16),
        danger: srgb(219, 104, 96),
        coverPaper: srgb(55, 54, 50),
        coverPaperShade: srgb(34, 35, 36, 0.8),
        coverDisc: srgb(15, 16, 18),
        coverGroove: srgb(242, 240, 234, 0.18),
        coverLabel: srgb(166, 101, 55),
        coverCenter: srgb(8, 9, 10),
        coverStroke: srgb(242, 240, 234, 0.14),
        coverSheen: .white.opacity(0.11)
    )

    static func of(_ theme: AppTheme) -> ThemeTokens {
        theme == .dark ? .dark : .light
    }
}

// MARK: - 封面占位与播放条氛围色

extension Album {
    func coverAccent(theme: AppTheme, alpha: Double = 1) -> Color {
        oklch(theme == .dark ? 0.62 : 0.52, theme == .dark ? 0.055 : 0.068, h1, alpha)
    }

    func coverAccentSoft(theme: AppTheme, alpha: Double = 1) -> Color {
        oklch(theme == .dark ? 0.52 : 0.76, theme == .dark ? 0.045 : 0.042, h2, alpha)
    }

    func playbarAmbient(theme: AppTheme, hue: Double, alpha: Double) -> Color {
        oklch(theme == .dark ? 0.55 : 0.64, theme == .dark ? 0.04 : 0.036, hue, alpha)
    }
}
