import AppKit
import DiffCore

/// The whole app is one window holding two strings: the original and the modified text.
/// Accepting a change copies the modified wording into the original; declining copies the
/// original wording back into the modified text. Either way the change disappears, and once
/// nothing is left the modified pane holds the final result.
final class MainWindowController: NSWindowController, NSTextViewDelegate, NSMenuItemValidation, NSSplitViewDelegate {
    private let originalPane = EditorPane(title: "원본")
    private let modifiedPane = EditorPane(title: "수정본 (결과)")
    private let inlineView = InlineDiffView()
    private let inlineScroll = NSScrollView()
    private let editorsSplit = NSSplitView()
    private let outerSplit = NSSplitView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var acceptButton: NSButton!
    private var declineButton: NSButton!

    private var result = DiffResult.empty
    private var selected: Int?
    private var pendingDiff: DispatchWorkItem?
    private var isApplyingEdit = false

    private static let fontSizeKey = "fontSize"
    private var fontSize: CGFloat = {
        let v = UserDefaults.standard.double(forKey: MainWindowController.fontSizeKey)
        return v > 0 ? CGFloat(v) : Theme.defaultFontSize
    }() {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: Self.fontSizeKey)
            applyFont()
        }
    }

    private var original: NSTextView { originalPane.textView }
    private var modified: NSTextView { modifiedPane.textView }

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "TextDiff"
        window.minSize = NSSize(width: 640, height: 420)
        super.init(window: window)
        buildLayout()
        window.center()
        window.setFrameAutosaveName("MainWindow")
        applyFont()
        #if DEBUG
        if let a = ProcessInfo.processInfo.environment["TEXTDIFF_A"],
           let b = ProcessInfo.processInfo.environment["TEXTDIFF_B"] {
            original.string = a
            modified.string = b
        }
        if ProcessInfo.processInfo.environment["TEXTDIFF_DARK"] != nil { NSApp.appearance = NSAppearance(named: .darkAqua) }
        if let s = ProcessInfo.processInfo.environment["TEXTDIFF_SELECT"], let id = Int(s) {
            DispatchQueue.main.async { self.recompute(); self.select(id) }
        }
        #endif
        recompute()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func buildLayout() {
        guard let content = window?.contentView else { return }

        for pane in [originalPane, modifiedPane] {
            pane.textView.delegate = self
        }
        originalPane.highlightColor = Theme.deletion
        modifiedPane.highlightColor = Theme.insertion

        editorsSplit.isVertical = true
        editorsSplit.dividerStyle = .thin
        editorsSplit.addArrangedSubview(originalPane)
        editorsSplit.addArrangedSubview(modifiedPane)

        inlineScroll.documentView = inlineView
        inlineScroll.hasVerticalScroller = true
        inlineScroll.borderType = .noBorder
        inlineView.minSize = NSSize(width: 0, height: 0)
        inlineView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        inlineView.onSelect = { [weak self] id in self?.select(id, scrollInline: false) }
        inlineView.onAccept = { [weak self] id in self?.accept(id) }
        inlineView.onDecline = { [weak self] id in self?.decline(id) }

        let inlinePane = NSView()
        let inlineTitle = EditorPane.titleLabel("비교")
        inlinePane.addSubview(inlineTitle)
        inlinePane.addSubview(inlineScroll)
        inlineScroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inlineTitle.topAnchor.constraint(equalTo: inlinePane.topAnchor, constant: 6),
            inlineTitle.leadingAnchor.constraint(equalTo: inlinePane.leadingAnchor, constant: 12),
            inlineScroll.topAnchor.constraint(equalTo: inlineTitle.bottomAnchor, constant: 4),
            inlineScroll.leadingAnchor.constraint(equalTo: inlinePane.leadingAnchor),
            inlineScroll.trailingAnchor.constraint(equalTo: inlinePane.trailingAnchor),
            inlineScroll.bottomAnchor.constraint(equalTo: inlinePane.bottomAnchor),
        ])

        outerSplit.isVertical = false
        outerSplit.dividerStyle = .paneSplitter
        outerSplit.delegate = self
        outerSplit.addArrangedSubview(editorsSplit)
        outerSplit.addArrangedSubview(inlinePane)

        let bar = buildToolbar()
        let separator = NSBox()
        separator.boxType = .separator

        for v in [bar, separator, outerSplit] {
            v.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(v)
        }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            separator.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            outerSplit.topAnchor.constraint(equalTo: separator.bottomAnchor),
            outerSplit.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            outerSplit.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            outerSplit.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        content.layoutSubtreeIfNeeded()
        editorsSplit.setPosition(editorsSplit.bounds.width / 2, ofDividerAt: 0)
        outerSplit.setPosition(outerSplit.bounds.height * 0.5, ofDividerAt: 0)
        outerSplit.autosaveName = "OuterSplit"
        editorsSplit.autosaveName = "EditorsSplit"
    }

    private func buildToolbar() -> NSView {
        func button(_ title: String, _ symbol: String?, _ action: Selector, tip: String) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .rounded
            b.controlSize = .regular
            if let symbol {
                b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
                b.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
            }
            b.toolTip = tip
            return b
        }
        let prev = button("", "chevron.up", #selector(selectPrevious(_:)), tip: "이전 변경 (⌘[)")
        let next = button("", "chevron.down", #selector(selectNext(_:)), tip: "다음 변경 (⌘])")
        acceptButton = button("수락", "checkmark", #selector(acceptSelected(_:)), tip: "선택한 변경 수락 (⌘↩)")
        acceptButton.contentTintColor = .systemGreen
        declineButton = button("거절", "xmark", #selector(declineSelected(_:)), tip: "선택한 변경 거절 (⇧⌘↩)")
        declineButton.contentTintColor = .systemRed
        let acceptAll = button("모두 수락", nil, #selector(acceptAll(_:)), tip: "모든 변경 수락")
        let declineAll = button("모두 거절", nil, #selector(declineAll(_:)), tip: "모든 변경 거절")
        let copy = button("결과 복사", "doc.on.doc", #selector(copyResult(_:)), tip: "수정본 전체 복사 (⇧⌘C)")
        let clear = button("", "trash", #selector(clearAll(_:)), tip: "모두 지우기")

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [prev, next, acceptButton, declineButton, gap(), acceptAll, declineAll,
                                         spacer, statusLabel, gap(), copy, clear])
        stack.orientation = .horizontal
        stack.spacing = 6
        return stack
    }

    private func gap() -> NSView {
        let v = NSView()
        v.widthAnchor.constraint(equalToConstant: 10).isActive = true
        return v
    }

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        subview !== editorsSplit
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        max(proposedMinimumPosition, 120)
    }

    // MARK: - Diffing

    func textDidChange(_ notification: Notification) {
        guard !isApplyingEdit else { return }
        scheduleDiff()
    }

    private func scheduleDiff() {
        pendingDiff?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.recompute() }
        pendingDiff = work
        // Short debounce keeps typing smooth on long texts while still feeling live.
        let length = original.string.utf16.count + modified.string.utf16.count
        DispatchQueue.main.asyncAfter(deadline: .now() + (length > 50_000 ? 0.3 : 0.08), execute: work)
    }

    private func recompute() {
        pendingDiff?.cancel()
        pendingDiff = nil
        result = Differ.diff(original.string, modified.string)
        let hunks = result.hunks

        originalPane.highlight(hunks.map { inner($0.original, $0) })
        modifiedPane.highlight(hunks.map { inner($0.modified, $0) })
        inlineView.render(result, fontSize: fontSize)
        if let s = selected, s >= hunks.count { selected = hunks.isEmpty ? nil : hunks.count - 1 }
        inlineView.selectedHunk = selected

        let count = hunks.count
        if original.string.isEmpty && modified.string.isEmpty {
            statusLabel.stringValue = ""
        } else if count == 0 {
            statusLabel.stringValue = "차이 없음"
        } else if let s = selected {
            statusLabel.stringValue = "변경 \(s + 1) / \(count)"
        } else {
            statusLabel.stringValue = "변경 \(count)개"
        }
        acceptButton.isEnabled = count > 0
        declineButton.isEnabled = count > 0
    }

    /// Highlight only the characters that differ, not the shared prefix/suffix.
    private func inner(_ r: NSRange, _ h: Hunk) -> NSRange {
        let len = r.length - h.sharedPrefix - h.sharedSuffix
        return NSRange(location: r.location + h.sharedPrefix, length: max(0, len))
    }

    private func ensureFresh() {
        if pendingDiff != nil { recompute() }
    }

    // MARK: - Selection

    private func select(_ id: Int?, scrollInline: Bool = true, revealInEditors: Bool = true) {
        selected = id
        inlineView.selectedHunk = id
        recomputeStatusOnly()
        guard let id, id < result.hunks.count else { return }
        if scrollInline { inlineView.scrollToHunk(id) }
        if revealInEditors {
            let h = result.hunks[id]
            originalPane.reveal(h.original)
            modifiedPane.reveal(h.modified)
        }
    }

    private func recomputeStatusOnly() {
        let count = result.hunks.count
        guard count > 0 else { return }
        statusLabel.stringValue = selected.map { "변경 \($0 + 1) / \(count)" } ?? "변경 \(count)개"
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isApplyingEdit, pendingDiff == nil,
              let tv = notification.object as? NSTextView, tv.window?.firstResponder === tv else { return }
        let loc = tv.selectedRange().location
        let isOriginal = tv === original
        let hit = result.hunks.first { h in
            let r = isOriginal ? h.original : h.modified
            return loc >= r.location && loc <= NSMaxRange(r)
        }
        if let hit, hit.id != selected {
            select(hit.id, revealInEditors: false)
        }
    }

    @objc func selectNext(_ sender: Any?) {
        ensureFresh()
        let n = result.hunks.count
        guard n > 0 else { return }
        select(selected.map { min($0 + 1, n - 1) } ?? 0)
    }

    @objc func selectPrevious(_ sender: Any?) {
        ensureFresh()
        let n = result.hunks.count
        guard n > 0 else { return }
        select(selected.map { max($0 - 1, 0) } ?? n - 1)
    }

    // MARK: - Accept / decline

    private func replace(in tv: NSTextView, range: NSRange, with text: String, actionName: String) {
        isApplyingEdit = true
        defer { isApplyingEdit = false }
        tv.breakUndoCoalescing()
        if tv.shouldChangeText(in: range, replacementString: text) {
            tv.textStorage?.replaceCharacters(in: range, with: NSAttributedString(string: text, attributes: tv.typingAttributes))
            tv.didChangeText()
            tv.undoManager?.setActionName(actionName)
        }
    }

    private func accept(_ id: Int) {
        ensureFresh()
        guard id < result.hunks.count else { return }
        let h = result.hunks[id]
        replace(in: original, range: h.original, with: h.modifiedText, actionName: "수락")
        afterResolve(id)
    }

    private func decline(_ id: Int) {
        ensureFresh()
        guard id < result.hunks.count else { return }
        let h = result.hunks[id]
        replace(in: modified, range: h.modified, with: h.originalText, actionName: "거절")
        afterResolve(id)
    }

    /// The resolved hunk disappears, so the same index now points at the next change.
    private func afterResolve(_ id: Int) {
        selected = id
        recompute()
        if let s = selected { select(s) }
    }

    @objc func acceptSelected(_ sender: Any?) {
        ensureFresh()
        if let s = selected { accept(s) } else if !result.hunks.isEmpty { select(0) }
    }

    @objc func declineSelected(_ sender: Any?) {
        ensureFresh()
        if let s = selected { decline(s) } else if !result.hunks.isEmpty { select(0) }
    }

    @objc func acceptAll(_ sender: Any?) {
        replace(in: original, range: NSRange(location: 0, length: original.string.utf16.count),
                with: modified.string, actionName: "모두 수락")
        selected = nil
        recompute()
    }

    @objc func declineAll(_ sender: Any?) {
        replace(in: modified, range: NSRange(location: 0, length: modified.string.utf16.count),
                with: original.string, actionName: "모두 거절")
        selected = nil
        recompute()
    }

    @objc func copyResult(_ sender: Any?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(modified.string, forType: .string)
        statusLabel.stringValue = "결과를 복사했습니다"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.recompute() }
    }

    @objc func clearAll(_ sender: Any?) {
        replace(in: original, range: NSRange(location: 0, length: original.string.utf16.count), with: "", actionName: "모두 지우기")
        replace(in: modified, range: NSRange(location: 0, length: modified.string.utf16.count), with: "", actionName: "모두 지우기")
        selected = nil
        recompute()
        window?.makeFirstResponder(original)
    }

    // MARK: - View

    @objc func toggleInline(_ sender: Any?) {
        let pane = outerSplit.arrangedSubviews[1]
        if outerSplit.isSubviewCollapsed(pane) {
            outerSplit.setPosition(outerSplit.bounds.height * 0.5, ofDividerAt: 0)
        } else {
            outerSplit.setPosition(outerSplit.bounds.height, ofDividerAt: 0)
        }
    }

    @objc func biggerFont(_ sender: Any?) { fontSize = min(fontSize + 1, 36) }
    @objc func smallerFont(_ sender: Any?) { fontSize = max(fontSize - 1, 9) }
    @objc func resetFont(_ sender: Any?) { fontSize = Theme.defaultFontSize }

    private func applyFont() {
        originalPane.setFont(Theme.font(size: fontSize))
        modifiedPane.setFont(Theme.font(size: fontSize))
        inlineView.render(result, fontSize: fontSize)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(acceptSelected(_:)), #selector(declineSelected(_:)),
             #selector(selectNext(_:)), #selector(selectPrevious(_:)),
             #selector(acceptAll(_:)), #selector(declineAll(_:)):
            return !result.hunks.isEmpty || pendingDiff != nil
        case #selector(toggleInline(_:)):
            item.state = outerSplit.isSubviewCollapsed(outerSplit.arrangedSubviews[1]) ? .off : .on
            return true
        default:
            return true
        }
    }
}
