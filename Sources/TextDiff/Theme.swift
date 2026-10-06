import AppKit

enum Theme {
    /// Colors follow picadiff (#ffc6c6 / #c6ffc6) in light mode, muted tints in dark mode.
    static let deletion = dynamic(light: NSColor(srgbRed: 1.0, green: 0.776, blue: 0.776, alpha: 1),
                                  dark: NSColor.systemRed.withAlphaComponent(0.35))
    static let insertion = dynamic(light: NSColor(srgbRed: 0.776, green: 1.0, blue: 0.776, alpha: 1),
                                   dark: NSColor.systemGreen.withAlphaComponent(0.35))
    static let deletionText = dynamic(light: NSColor(srgbRed: 0.6, green: 0.1, blue: 0.1, alpha: 1),
                                      dark: NSColor(srgbRed: 1.0, green: 0.62, blue: 0.62, alpha: 1))

    static let defaultFontSize: CGFloat = 14

    static func font(size: CGFloat) -> NSFont { .systemFont(ofSize: size) }

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }
}

extension NSAttributedString.Key {
    /// Marks inline-diff text that belongs to a hunk; value is the hunk id (Int).
    static let hunkID = NSAttributedString.Key("TextDiff.hunkID")
}
