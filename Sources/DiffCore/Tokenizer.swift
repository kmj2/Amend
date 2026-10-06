import Foundation

/// A slice of the source text used as the unit of comparison.
public struct Token: Equatable, Sendable {
    public enum Kind: Sendable { case word, space, newline, symbol }

    public let text: String
    public let kind: Kind
    /// Location in the source string, in UTF-16 code units (NSString/NSRange space).
    public let utf16Range: Range<Int>
}

public enum Tokenizer {
    /// Splits text into words (letters, digits, marks), whitespace runs, single newlines
    /// and single symbol characters. Concatenating every token's text reproduces the input.
    public static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var currentKind: Token.Kind?
        var start = 0
        var offset = 0

        func flush() {
            guard let kind = currentKind else { return }
            tokens.append(Token(text: current, kind: kind, utf16Range: start..<offset))
            current = ""
            currentKind = nil
        }

        for ch in text {
            let kind = classify(ch)
            let joins = kind == currentKind && (kind == .word || kind == .space)
            if !joins {
                flush()
                start = offset
                currentKind = kind
            }
            current.append(ch)
            offset += ch.utf16.count
        }
        flush()
        return tokens
    }

    static func classify(_ ch: Character) -> Token.Kind {
        if ch.isNewline { return .newline }
        if ch.isWhitespace { return .space }
        if ch.isLetter || ch.isNumber || ch == "_" { return .word }
        // Combining marks attached to a letter are part of the same Character already;
        // a lone mark is still word-like.
        if ch.unicodeScalars.allSatisfy({ $0.properties.generalCategory.isMark }) { return .word }
        return .symbol
    }
}

private extension Unicode.GeneralCategory {
    var isMark: Bool {
        switch self {
        case .nonspacingMark, .spacingMark, .enclosingMark: return true
        default: return false
        }
    }
}
