import AppKit

/// A titled, editable plain-text area whose differing ranges are tinted.
final class EditorPane: NSView {
    let textView: NSTextView
    var highlightColor: NSColor = .clear
    let scrollView: NSScrollView

    init(title: String) {
        scrollView = NSTextView.scrollableTextView()
        textView = scrollView.documentView as! NSTextView
        super.init(frame: .zero)

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        scrollView.borderType = .noBorder
        scrollView.contentView.postsBoundsChangedNotifications = true

        let label = Self.titleLabel(title)
        for v in [label, scrollView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    static func titleLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    func setFont(_ font: NSFont) {
        textView.font = font
        textView.typingAttributes[.font] = font
    }

    /// Temporary attributes don't touch the text storage, so they never enter undo history.
    func highlight(_ ranges: [NSRange]) {
        guard let lm = textView.layoutManager else { return }
        let length = textView.string.utf16.count
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: length))
        for r in ranges where r.length > 0 && NSMaxRange(r) <= length {
            lm.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: r)
        }
    }

    // MARK: - Scroll position as text location

    /// The character at the top of the visible area, and how far (in points) the view is
    /// scrolled past the top of that character's line.
    func topLocation() -> (index: Int, lineOffset: CGFloat)? {
        guard let lm = textView.layoutManager, let tc = textView.textContainer, textView.string.utf16.count > 0 else { return nil }
        let y = scrollView.contentView.bounds.minY - textView.textContainerOrigin.y
        let glyph = lm.glyphIndex(for: NSPoint(x: 0, y: max(0, y)), in: tc)
        let line = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        return (lm.characterIndexForGlyph(at: glyph), y - line.minY)
    }

    func scroll(toLocation index: Int, lineOffset: CGFloat) {
        guard let lm = textView.layoutManager else { return }
        let length = textView.string.utf16.count
        var y: CGFloat = 0
        if length > 0 {
            let glyph = lm.glyphIndexForCharacter(at: min(index, length - 1))
            lm.ensureLayout(forGlyphRange: NSRange(location: 0, length: glyph + 1))
            let line = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            y = line.minY + textView.textContainerOrigin.y + min(max(lineOffset, 0), line.height)
        }
        scrollTo(y: y)
    }

    var isScrolledToBottom: Bool {
        let clip = scrollView.contentView
        return clip.bounds.maxY >= textView.frame.height - 1 && clip.bounds.minY > 0
    }

    func scrollToBottom() { scrollTo(y: .greatestFiniteMagnitude) }

    private func scrollTo(y: CGFloat) {
        let clip = scrollView.contentView
        let maxY = max(0, textView.frame.height - clip.bounds.height)
        clip.scroll(to: NSPoint(x: clip.bounds.minX, y: min(max(0, y), maxY)))
        scrollView.reflectScrolledClipView(clip)
    }

    func reveal(_ range: NSRange) {
        guard NSMaxRange(range) <= textView.string.utf16.count else { return }
        textView.scrollRangeToVisible(range)
        if range.length > 0 { textView.showFindIndicator(for: range) }
    }
}
