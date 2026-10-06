import Foundation

/// One contiguous change between the original (A) and modified (B) text.
public struct Hunk: Equatable, Sendable, Identifiable {
    public let id: Int
    /// Range in the original text (UTF-16). Empty for pure insertions.
    public let original: NSRange
    /// Range in the modified text (UTF-16). Empty for pure deletions.
    public let modified: NSRange
    public let originalText: String
    public let modifiedText: String
    /// UTF-16 lengths of text shared at the start/end of both sides, so a view can
    /// highlight only the characters that actually differ (e.g. a changed particle).
    public let sharedPrefix: Int
    public let sharedSuffix: Int
}

public enum Segment: Equatable, Sendable {
    case equal(String)
    case change(Hunk)
}

public struct DiffResult: Equatable, Sendable {
    public let segments: [Segment]
    public var hunks: [Hunk] {
        segments.compactMap { if case .change(let h) = $0 { h } else { nil } }
    }
    public static let empty = DiffResult(segments: [])

    /// Maps a UTF-16 offset in one text to the corresponding offset in the other.
    /// Offsets inside a change map to the start of that change on the other side.
    public func mapOffset(_ offset: Int, fromOriginal: Bool) -> Int {
        var delta = 0
        for h in hunks {
            let (src, dst) = fromOriginal ? (h.original, h.modified) : (h.modified, h.original)
            if offset < src.location { break }
            if offset < NSMaxRange(src) { return dst.location }
            delta = NSMaxRange(dst) - NSMaxRange(src)
        }
        return max(0, offset + delta)
    }
}

public enum Differ {
    public static func diff(_ original: String, _ modified: String) -> DiffResult {
        let a = Tokenizer.tokenize(original)
        let b = Tokenizer.tokenize(modified)
        let ops = cleanup(align(a, b), a, b)
        return build(ops, a, b)
    }

    /// Accepting a change makes the original match the modified text for that hunk.
    public static func accept(_ hunk: Hunk, in original: String) -> String {
        (original as NSString).replacingCharacters(in: hunk.original, with: hunk.modifiedText)
    }

    /// Rejecting a change restores the original wording inside the modified text.
    public static func reject(_ hunk: Hunk, in modified: String) -> String {
        (modified as NSString).replacingCharacters(in: hunk.modified, with: hunk.originalText)
    }

    // MARK: - Internals

    struct Op: Equatable {
        var isEqual: Bool
        var a: Range<Int>  // token indices
        var b: Range<Int>
    }

    /// Myers diff over tokens, turned into alternating equal/change runs.
    static func align(_ a: [Token], _ b: [Token]) -> [Op] {
        let diff = b.map(\.text).difference(from: a.map(\.text))
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in diff {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }

        var ops: [Op] = []
        var i = 0, j = 0
        while i < a.count || j < b.count {
            let si = i, sj = j
            while i < a.count, j < b.count, !removed.contains(i), !inserted.contains(j) {
                i += 1; j += 1
            }
            if i > si { ops.append(Op(isEqual: true, a: si..<i, b: sj..<j)) }

            let ci = i, cj = j
            var advanced = true
            while advanced {
                advanced = false
                while i < a.count, removed.contains(i) { i += 1; advanced = true }
                while j < b.count, inserted.contains(j) { j += 1; advanced = true }
            }
            if i > ci || j > cj { ops.append(Op(isEqual: false, a: ci..<i, b: cj..<j)) }
        }
        return ops
    }

    /// Semantic cleanup in the spirit of diff-match-patch: a short equality sandwiched
    /// between two changes is folded into one change, which reads far better than
    /// "word ~~x~~y word ~~z~~w". Equalities containing a newline are kept so that
    /// paragraphs stay independently acceptable.
    static func cleanup(_ ops: [Op], _ a: [Token], _ b: [Token]) -> [Op] {
        func len(_ tokens: [Token], _ r: Range<Int>) -> Int {
            r.reduce(0) { $0 + tokens[$1].utf16Range.count }
        }
        func editSize(_ op: Op) -> Int { max(len(a, op.a), len(b, op.b)) }

        var out: [Op] = []
        var k = 0
        while k < ops.count {
            let op = ops[k]
            if op.isEqual, let prev = out.last, !prev.isEqual, k + 1 < ops.count {
                let next = ops[k + 1]
                let size = len(a, op.a)
                let hasNewline = op.a.contains { a[$0].kind == .newline }
                if !hasNewline, size <= editSize(prev), size <= editSize(next) {
                    out[out.count - 1] = Op(
                        isEqual: false,
                        a: prev.a.lowerBound..<next.a.upperBound,
                        b: prev.b.lowerBound..<next.b.upperBound)
                    k += 2
                    continue
                }
            }
            out.append(op)
            k += 1
        }
        return out
    }

    static func build(_ ops: [Op], _ a: [Token], _ b: [Token]) -> DiffResult {
        func range(_ tokens: [Token], _ r: Range<Int>, fallback: Int) -> NSRange {
            guard let first = r.first, let last = r.last else { return NSRange(location: fallback, length: 0) }
            let lo = tokens[first].utf16Range.lowerBound
            return NSRange(location: lo, length: tokens[last].utf16Range.upperBound - lo)
        }
        func text(_ tokens: [Token], _ r: Range<Int>) -> String {
            r.map { tokens[$0].text }.joined()
        }

        var segments: [Segment] = []
        var aPos = 0, bPos = 0, nextID = 0
        for op in ops {
            let ar = range(a, op.a, fallback: aPos)
            let br = range(b, op.b, fallback: bPos)
            aPos = NSMaxRange(ar); bPos = NSMaxRange(br)
            if op.isEqual {
                segments.append(.equal(text(a, op.a)))
            } else {
                let at = text(a, op.a), bt = text(b, op.b)
                let (pre, suf) = shared(at, bt)
                segments.append(.change(Hunk(
                    id: nextID, original: ar, modified: br,
                    originalText: at, modifiedText: bt,
                    sharedPrefix: pre, sharedSuffix: suf)))
                nextID += 1
            }
        }
        return DiffResult(segments: segments)
    }

    static let minShared = 2

    /// Common prefix/suffix by Character, reported in UTF-16 units; never overlapping.
    static func shared(_ x: String, _ y: String) -> (Int, Int) {
        guard !x.isEmpty, !y.isEmpty else { return (0, 0) }
        // Across several words ("has a" → "have an") a partial highlight is confusing;
        // show the whole phrase replaced instead.
        guard !x.contains(where: \.isWhitespace), !y.contains(where: \.isWhitespace) else { return (0, 0) }
        let xc = Array(x), yc = Array(y)
        var p = 0
        while p < xc.count, p < yc.count, xc[p] == yc[p] { p += 1 }
        var s = 0
        while s < xc.count - p, s < yc.count - p, xc[xc.count - 1 - s] == yc[yc.count - 1 - s] { s += 1 }
        // A single shared letter ("w" in were→was) splits a word in a way that reads worse
        // than showing the whole word replaced.
        if p < minShared { p = 0 }
        if s < minShared { s = 0 }
        let u16 = { (cs: ArraySlice<Character>) in cs.reduce(0) { $0 + $1.utf16.count } }
        return (u16(xc[..<p]), u16(xc[(xc.count - s)...]))
    }
}
