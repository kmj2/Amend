import AppKit
import DiffCore

/// Read-only unified view in the style of PrettyTextDiff: deletions struck through in red,
/// insertions in green. Clicking a change selects it and shows accept/reject buttons.
final class InlineDiffView: NSTextView {
    var onSelect: ((Int?) -> Void)?
    var onAccept: ((Int) -> Void)?
    var onReject: ((Int) -> Void)?

    private(set) var hunkRanges: [Int: NSRange] = [:]
    private let actionBar = HunkActionBar()

    var selectedHunk: Int? {
        didSet { if oldValue != selectedHunk { layoutActionBar(); needsDisplay = true } }
    }

    convenience init() {
        self.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isRichText = true
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        textContainerInset = NSSize(width: 10, height: 10)
        isVerticallyResizable = true
        autoresizingMask = [.width]
        textContainer?.widthTracksTextView = true

        actionBar.isHidden = true
        actionBar.onAccept = { [weak self] in
            if let id = self?.selectedHunk { self?.onAccept?(id) }
        }
        actionBar.onReject = { [weak self] in
            if let id = self?.selectedHunk { self?.onReject?(id) }
        }
        addSubview(actionBar)
    }

    func render(_ result: DiffResult, fontSize: CGFloat) {
        let font = Theme.font(size: fontSize)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 3
        let base: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: para,
        ]
        let del: [NSAttributedString.Key: Any] = base.merging([
            .backgroundColor: Theme.deletion,
            .foregroundColor: Theme.deletionText,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
        ]) { $1 }
        let ins: [NSAttributedString.Key: Any] = base.merging([.backgroundColor: Theme.insertion]) { $1 }

        let out = NSMutableAttributedString()
        var ranges: [Int: NSRange] = [:]
        for segment in result.segments {
            switch segment {
            case .equal(let text):
                out.append(NSAttributedString(string: text, attributes: base))
            case .change(let h):
                let start = out.length
                let a = h.originalText as NSString, b = h.modifiedText as NSString
                let prefix = a.substring(to: h.sharedPrefix)
                let suffix = a.substring(from: a.length - h.sharedSuffix)
                let removed = a.substring(with: NSRange(location: h.sharedPrefix, length: a.length - h.sharedPrefix - h.sharedSuffix))
                let added = b.substring(with: NSRange(location: h.sharedPrefix, length: b.length - h.sharedPrefix - h.sharedSuffix))
                out.append(NSAttributedString(string: prefix, attributes: base))
                out.append(NSAttributedString(string: visible(removed), attributes: del))
                out.append(NSAttributedString(string: visible(added), attributes: ins))
                out.append(NSAttributedString(string: suffix, attributes: base))
                let r = NSRange(location: start, length: out.length - start)
                out.addAttribute(.hunkID, value: h.id, range: r)
                ranges[h.id] = r
            }
        }
        if out.length == 0 {
            out.append(NSAttributedString(string: "Paste the original and revised text above to see the differences here.",
                                          attributes: base.merging([.foregroundColor: NSColor.placeholderTextColor]) { $1 }))
        }
        hunkRanges = ranges
        textStorage?.setAttributedString(out)
        if let id = selectedHunk, ranges[id] == nil { selectedHunk = nil }
        layoutActionBar()
        needsDisplay = true
    }

    /// Whitespace-only changes would be invisible; show line breaks and spaces explicitly.
    private func visible(_ s: String) -> String {
        if s.isEmpty { return s }
        var r = s.replacingOccurrences(of: "\n", with: "¶\n")
        if r.allSatisfy({ $0 == " " || $0 == "\t" }) {
            r = r.replacingOccurrences(of: " ", with: "·").replacingOccurrences(of: "\t", with: "→")
        }
        return r
    }

    func scrollToHunk(_ id: Int) {
        guard let r = hunkRanges[id] else { return }
        scrollRangeToVisible(r)
        // Keep the action bar in view as well.
        scrollToVisible(actionBar.frame.insetBy(dx: 0, dy: -8))
    }

    // MARK: - Hit testing

    private func hunk(at point: NSPoint) -> Int? {
        guard let lm = layoutManager, let tc = textContainer, let storage = textStorage, storage.length > 0 else { return nil }
        let p = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        var fraction: CGFloat = 0
        let glyph = lm.glyphIndex(for: p, in: tc, fractionOfDistanceThroughGlyph: &fraction)
        let rect = lm.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: tc)
        guard rect.insetBy(dx: -2, dy: -2).contains(p) else { return nil }
        let index = lm.characterIndexForGlyph(at: glyph)
        guard index < storage.length else { return nil }
        return storage.attribute(.hunkID, at: index, effectiveRange: nil) as? Int
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?(hunk(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseMoved(with event: NSEvent) {
        if hunk(at: convert(event.locationInWindow, from: nil)) != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self && $0.userInfo?["inline"] != nil }.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: ["inline": true]))
    }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: .arrow)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutActionBar()
    }

    // MARK: - Selection drawing

    private func rects(for range: NSRange) -> [NSRect] {
        guard let lm = layoutManager, let tc = textContainer else { return [] }
        let glyphs = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var out: [NSRect] = []
        lm.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: tc) { r, _ in
            out.append(r.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y))
        }
        return out
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let id = selectedHunk, let r = hunkRanges[id] else { return }
        NSColor.controlAccentColor.setStroke()
        for rect in rects(for: r) {
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: -2, dy: -1), xRadius: 3, yRadius: 3)
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    private func layoutActionBar() {
        guard let id = selectedHunk, let r = hunkRanges[id], let last = rects(for: r).last else {
            actionBar.isHidden = true
            return
        }
        let size = actionBar.fittingSize
        var x = last.minX
        x = min(x, bounds.width - size.width - 8)
        x = max(x, 8)
        actionBar.frame = NSRect(x: x, y: last.maxY + 4, width: size.width, height: size.height)
        actionBar.isHidden = false
    }
}

/// Small floating "✓ Accept  ✕ Reject" pill shown under the selected change.
final class HunkActionBar: NSView {
    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        shadow = NSShadow()
        layer?.shadowOpacity = 0.15
        layer?.shadowRadius = 3
        layer?.shadowOffset = CGSize(width: 0, height: -1)

        let accept = button("Accept", symbol: "checkmark", color: .systemGreen, action: #selector(acceptTapped))
        let reject = button("Reject", symbol: "xmark", color: .systemRed, action: #selector(rejectTapped))
        let stack = NSStackView(views: [accept, reject])
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
    override var wantsUpdateLayer: Bool { true }

    private func button(_ title: String, symbol: String, color: NSColor, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .recessed
        b.isBordered = false
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        b.imagePosition = .imageLeading
        b.contentTintColor = color
        b.font = .systemFont(ofSize: 12, weight: .medium)
        return b
    }

    @objc private func acceptTapped() { onAccept?() }
    @objc private func rejectTapped() { onReject?() }
}
