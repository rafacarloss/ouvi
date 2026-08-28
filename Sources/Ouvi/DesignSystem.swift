import AppKit
import CoreText
import SwiftUI

/// Ouvi design tokens, translated from design/tokens/*.css.
/// Light = "paper" (warm neutrals); dark = "graphite" (cool, never pure black).
/// Signal green means exactly one thing: Ouvi is listening / is local.
enum DS {
    // MARK: Color primitives

    private static func dynamic(_ light: String, _ dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    private static func dynamicAlpha(_ light: (String, CGFloat), _ dark: (String, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let (hex, alpha) = isDark ? dark : light
            return NSColor(hex: hex).withAlphaComponent(alpha)
        })
    }

    // MARK: Semantic colors

    static let bgWindow = dynamic("#fbfbf9", "#121315")
    static let bgSidebar = dynamic("#f4f4f1", "#16181a")
    static let bgSurface = dynamic("#ffffff", "#1a1c1f")
    static let bgInset = dynamic("#f4f4f1", "#16181a")
    static let bgHover = dynamicAlpha(("#121416", 0.045), ("#ffffff", 0.055))
    static let bgActive = dynamicAlpha(("#121416", 0.08), ("#ffffff", 0.10))
    static let bgSelected = dynamic("#e4f4ec", "#12281f")

    static let textTitle = dynamic("#16181a", "#f1f2f2")
    static let textBody = dynamic("#16181a", "#f1f2f2")
    static let textMuted = dynamic("#55595e", "#a6acb2")
    static let textFaint = dynamic("#8b9096", "#71777d")
    static let textDraft = textFaint
    static let textOnAccent = dynamic("#ffffff", "#08130d")

    static let borderHairline = dynamicAlpha(("#121416", 0.09), ("#ffffff", 0.09))
    static let borderStrong = dynamicAlpha(("#121416", 0.16), ("#ffffff", 0.16))

    static let accent = dynamic("#2e9e6b", "#3fb87f")
    static let accentHover = dynamic("#237f56", "#58c894")
    static let accentSoft = dynamic("#e4f4ec", "#12281f")
    static let accentSoftText = dynamic("#1a6244", "#8fdcb5")

    static let live = accent
    static let liveGlow = dynamicAlpha(("#2e9e6b", 0.28), ("#3fb87f", 0.35))
    static let danger = dynamic("#c4462f", "#e0664c")
    static let dangerSoft = dynamic("#fbe9e5", "#2c1512")
    static let caution = dynamic("#b7791f", "#d69b3c")
    static let cautionSoft = dynamic("#fbf1dd", "#2a1f0d")

    /// Fixed 5-slot speaker palette: me/green, then blue, ochre, violet, teal.
    /// Used only for 3px name-side rules and dots — never text, never fills.
    static let speakerMe = dynamic("#237f56", "#58c894")
    static let speakerPalette: [Color] = [
        dynamic("#3b6fd4", "#6c95e6"),
        dynamic("#8f5d13", "#d69b3c"),
        dynamic("#7a4bbd", "#a98ae0"),
        dynamic("#1f7f85", "#4fb3ba"),
    ]

    static func speakerColor(for id: String?) -> Color {
        guard let id else { return speakerPalette[0] }
        return speakerPalette[abs(id.hashValue) % speakerPalette.count]
    }

    // MARK: Typography — Chivo for humans, Space Mono for machine facts.

    private static var chivoAvailable: Bool = {
        NSFont(name: "Chivo", size: 13) != nil || NSFont(name: "Chivo Regular", size: 13) != nil
    }()

    private static var monoAvailable: Bool = {
        NSFont(name: "Space Mono", size: 12) != nil
    }()

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        chivoAvailable
            ? Font.custom("Chivo", size: size).weight(weight)
            : Font.system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        monoAvailable
            ? Font.custom("Space Mono", size: size).weight(weight)
            : Font.system(size: size, weight: weight, design: .monospaced)
    }

    // Composed roles (sizes are the macOS-native 13px baseline scale).
    static let title1 = sans(23, .bold)
    static let title2 = sans(19, .medium)
    static let title3 = sans(16, .medium)
    static let body = sans(13)
    static let bodyMedium = sans(13, .medium)
    static let reading = sans(14)
    static let caption = sans(12)
    static let micro = sans(10, .medium)
    static let monoBody = mono(12)
    static let monoXS = mono(11)

    // MARK: Radii and spacing

    static let radiusControl: CGFloat = 5
    static let radiusCard: CGFloat = 10
    static let radiusSheet: CGFloat = 14
    static let sidebarWidth: CGFloat = 248
    static let transcriptWidth: CGFloat = 340

    // MARK: Font registration (bundled Chivo variable + Space Mono, OFL)

    static func registerFonts() {
        let names = ["Chivo-Variable", "SpaceMono-Regular", "SpaceMono-Bold"]
        for name in names {
            guard let url = Bundle.module.url(forResource: "Fonts/\(name)", withExtension: "ttf")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf")
            else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        // Recompute availability after registration.
        chivoAvailable = NSFont(name: "Chivo", size: 13) != nil || NSFont(name: "Chivo Regular", size: 13) != nil
        monoAvailable = NSFont(name: "Space Mono", size: 12) != nil
    }
}

extension NSColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        var hexString = hex
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        Scanner(string: hexString).scanHexInt64(&value)
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1)
    }
}

// MARK: Shared components

/// Mono uppercase micro label (`LOCAL`, `AO VIVO`, `RASCUNHO`).
struct MicroBadge: View {
    let text: String
    var color: Color = DS.accentSoftText
    var background: Color = DS.accentSoft

    var body: some View {
        Text(text)
            .font(DS.mono(10, .bold))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background, in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Timecode in Space Mono — the strongest "machine fact" signal in the product.
struct TimeCode: View {
    let ms: Int
    var body: some View {
        Text(String(format: "%02d:%02d", ms / 60000, (ms / 1000) % 60))
            .font(DS.monoXS)
            .foregroundStyle(DS.textFaint)
    }
}
