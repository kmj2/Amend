import XCTest
@testable import DiffCore

final class TokenizerTests: XCTestCase {
    func testRoundTrip() {
        let samples = ["", "hello", "Hello, world!\n  Next  line.", "사과를 먹었다. 😀👍🏽 e\u{301}", "a\r\nb"]
        for s in samples {
            XCTAssertEqual(Tokenizer.tokenize(s).map(\.text).joined(), s)
        }
    }

    func testKinds() {
        let t = Tokenizer.tokenize("사과를  먹었다,\n")
        XCTAssertEqual(t.map(\.text), ["사과를", "  ", "먹었다", ",", "\n"])
        XCTAssertEqual(t.map(\.kind), [.word, .space, .word, .symbol, .newline])
    }

    func testUTF16Ranges() {
        let s = "😀 hi"
        let t = Tokenizer.tokenize(s)
        XCTAssertEqual(t.map(\.utf16Range), [0..<2, 2..<3, 3..<5])
    }
}

final class DifferTests: XCTestCase {
    func testIdentical() {
        XCTAssertTrue(Differ.diff("same text", "same text").hunks.isEmpty)
    }

    func testEmptySides() {
        XCTAssertEqual(Differ.diff("", "new").hunks.map(\.modifiedText), ["new"])
        XCTAssertEqual(Differ.diff("old", "").hunks.map(\.originalText), ["old"])
        XCTAssertTrue(Differ.diff("", "").segments.isEmpty)
    }

    func testWordReplacementWithSharedPrefix() {
        let h = Differ.diff("나는 사과를 먹었다.", "나는 사과가 먹었다.").hunks
        XCTAssertEqual(h.count, 1)
        XCTAssertEqual(h[0].originalText, "사과를")
        XCTAssertEqual(h[0].modifiedText, "사과가")
        XCTAssertEqual(h[0].sharedPrefix, 2)
        XCTAssertEqual(h[0].sharedSuffix, 0)
    }

    func testSingleSharedLetterIsNotSplit() {
        let h = Differ.diff("It were fine", "It was fine").hunks
        XCTAssertEqual(h.map(\.sharedPrefix), [0])
        XCTAssertEqual(Differ.diff("jump", "jumps").hunks.map(\.sharedPrefix), [4])
        XCTAssertEqual(Differ.diff("I has a pen", "I have an pen").hunks.map(\.sharedPrefix), [0])
    }

    func testCleanupMergesAcrossShortEquality() {
        // Whitespace (or a word shorter than the edits) between two edits is folded in.
        var h = Differ.diff("I saw big red dogs.", "I saw small blue dogs.").hunks
        XCTAssertEqual(h.map(\.originalText), ["big red"])
        XCTAssertEqual(h.map(\.modifiedText), ["small blue"])
        h = Differ.diff("alpha is gamma", "delta is omega").hunks
        XCTAssertEqual(h.map(\.modifiedText), ["delta is omega"])
    }

    func testNewlineKeepsHunksSeparate() {
        let h = Differ.diff("one\ntwo", "uno\ndos").hunks
        XCTAssertEqual(h.map(\.originalText), ["one", "two"])
    }

    func testLongEqualityKeepsHunksSeparate() {
        let h = Differ.diff("cat sat on the mat today", "dog sat on the mat tonight").hunks
        XCTAssertEqual(h.map(\.modifiedText), ["dog", "tonight"])
    }

    func testSegmentsReconstructBothTexts() {
        let a = "The quick brown fox jumps over the lazy dog.\n둘째 줄입니다."
        let b = "A quick red fox jumped over the dog!\n둘째 줄이에요. 추가"
        let r = Differ.diff(a, b)
        var ra = "", rb = ""
        for s in r.segments {
            switch s {
            case .equal(let t): ra += t; rb += t
            case .change(let h): ra += h.originalText; rb += h.modifiedText
            }
        }
        XCTAssertEqual(ra, a)
        XCTAssertEqual(rb, b)
    }

    func testAcceptAndRejectConverge() {
        let a = "Hello wrld, this are test.\nKeep me."
        let b = "Hello world, this is a test.\nKeep me!"
        var x = a, y = b
        // Accept the first, reject the rest — always re-diff after each action.
        var first = true
        while let h = Differ.diff(x, y).hunks.first {
            if first { x = Differ.accept(h, in: x); first = false }
            else { y = Differ.reject(h, in: y) }
        }
        XCTAssertEqual(x, y)
        XCTAssertTrue(x.hasPrefix("Hello world"))
        XCTAssertTrue(x.hasSuffix("Keep me."))
    }

    func testAcceptAllEqualsModified() {
        let a = "가나다 라마바\n사아자", b = "가나 라마바사\n차카타"
        var x = a
        while let h = Differ.diff(x, b).hunks.first { x = Differ.accept(h, in: x) }
        XCTAssertEqual(x, b)
    }

    func testMapOffset() {
        let a = "aaa bb cc\nkeep"
        let b = "aaa XXXXX cc\nkeep"
        let r = Differ.diff(a, b)
        XCTAssertEqual(r.mapOffset(0, fromOriginal: true), 0)
        XCTAssertEqual(r.mapOffset(5, fromOriginal: true), 4)   // inside "bb" -> start of "XXXXX"
        XCTAssertEqual(r.mapOffset(10, fromOriginal: true), 13) // "keep"
        XCTAssertEqual(r.mapOffset(13, fromOriginal: false), 10)
    }

    func testLargeInputPerformance() {
        let words = (0..<4000).map { "word\($0 % 300)" }
        let a = words.joined(separator: " ")
        let b = words.enumerated().map { $0.offset % 37 == 0 ? "changed" : $0.element }.joined(separator: " ")
        measure { _ = Differ.diff(a, b) }
    }
}
