import XCTest
@testable import Pasted

/// Tests for FuzzyMatcher: tier scoring, case insensitivity, multi-word AND logic, and edge cases.
final class FuzzyMatcherTests: XCTestCase {

    // MARK: - Tier 1: Exact whole-word match (≥ 1000)

    func testExactWordMatch_singleWord() {
        XCTAssertGreaterThanOrEqual(FuzzyMatcher.score("netflix", in: "Netflix account"), 1000)
    }

    func testExactWordMatch_caseInsensitive() {
        XCTAssertGreaterThanOrEqual(FuzzyMatcher.score("HELLO", in: "Hello World"), 1000)
    }

    func testExactWordMatch_secondWordInText() {
        XCTAssertGreaterThanOrEqual(FuzzyMatcher.score("world", in: "Hello World"), 1000)
    }

    // MARK: - Tier 2: Word prefix match (≥ 500, < 1000)

    func testWordPrefix_matchesPartialWord() {
        let s = FuzzyMatcher.score("saf", in: "Safari is open")
        XCTAssertGreaterThanOrEqual(s, 500)
        XCTAssertLessThan(s, 1000)
    }

    func testWordPrefix_shortPrefix() {
        let s = FuzzyMatcher.score("ne", in: "Netflix account")
        XCTAssertGreaterThanOrEqual(s, 500)
        XCTAssertLessThan(s, 1000)
    }

    func testWordPrefix_secondWordPrefix() {
        let s = FuzzyMatcher.score("acc", in: "Netflix account")
        XCTAssertGreaterThanOrEqual(s, 500)
        XCTAssertLessThan(s, 1000)
    }

    // MARK: - Tier 3: Substring match (≥ 200, < 500)

    func testSubstringMatch_midWord() {
        // "etfl" appears mid-word in "netflix" (e-t-f-l at positions 1-4) but not at word start
        let s = FuzzyMatcher.score("etfl", in: "Netflix account")
        XCTAssertGreaterThanOrEqual(s, 200)
        XCTAssertLessThan(s, 500)
    }

    func testSubstringMatch_acrossWords() {
        // "o w" contains a space — appears literally in "hello world" but not as a word prefix
        let s = FuzzyMatcher.score("o w", in: "hello world")
        XCTAssertGreaterThanOrEqual(s, 200)
        XCTAssertLessThan(s, 500)
    }

    // MARK: - Tier 4: Scattered subsequence (≥ 50, < 200)

    func testSubsequenceMatch_nflx_netflix() {
        let s = FuzzyMatcher.score("nflx", in: "Netflix")
        XCTAssertGreaterThanOrEqual(s, 50)
        XCTAssertLessThan(s, 200)
    }

    func testSubsequenceMatch_hwr_helloWorld() {
        let s = FuzzyMatcher.score("hwr", in: "Hello World")
        XCTAssertGreaterThanOrEqual(s, 50)
        XCTAssertLessThan(s, 200)
    }

    func testSubsequenceMatch_caseInsensitive() {
        let s = FuzzyMatcher.score("HWR", in: "Hello World")
        XCTAssertGreaterThanOrEqual(s, 50)
        XCTAssertLessThan(s, 200)
    }

    // MARK: - No match (0)

    func testNoMatch_returnsZero() {
        XCTAssertEqual(FuzzyMatcher.score("xyzabc", in: "Hello World"), 0)
    }

    func testNoMatch_charNotInText() {
        // 'z' does not appear in "Hello World"
        XCTAssertEqual(FuzzyMatcher.score("hz", in: "Hello World"), 0)
    }

    func testNoMatch_wrongOrder() {
        // 'r' appears before 'h' in "World Hello" — but as subsequence it still works
        // Opposite: "wh" from "Hello World" — 'w' appears at index 6, 'h' at 0, out of order
        XCTAssertEqual(FuzzyMatcher.score("wh", in: "Hello World"), 0)
    }

    // MARK: - Tier ordering

    func testTierOrdering_exactBeatsPrefix() {
        let exact = FuzzyMatcher.score("hello", in: "hello world")     // whole word → tier 1
        let prefix = FuzzyMatcher.score("hel", in: "hello world")      // prefix → tier 2
        XCTAssertGreaterThan(exact, prefix)
    }

    func testTierOrdering_prefixBeatsSubstring() {
        let prefix = FuzzyMatcher.score("net", in: "Netflix")           // word prefix → tier 2
        let substring = FuzzyMatcher.score("etf", in: "Netflix")       // mid-word substring → tier 3
        XCTAssertGreaterThan(prefix, substring)
    }

    func testTierOrdering_substringBeatsSubsequence() {
        let substring = FuzzyMatcher.score("etf", in: "Netflix")       // substring → tier 3
        let subsequence = FuzzyMatcher.score("nfx", in: "Netflix")     // subsequence → tier 4
        XCTAssertGreaterThan(substring, subsequence)
    }

    // MARK: - Multi-word (AND semantics)

    func testMultiWord_bothTokensMatch() {
        let s = FuzzyMatcher.scoreMultiWord("hello world", in: "Hello World greeting")
        XCTAssertGreaterThan(s, 0)
    }

    func testMultiWord_oneTokenMissing_returnsZero() {
        let s = FuzzyMatcher.scoreMultiWord("hello zzznope", in: "Hello World")
        XCTAssertEqual(s, 0)
    }

    func testMultiWord_scoreIsMinTokenScore() {
        // "hello" → tier 1 (1000), "wor" → tier 2 (500). Min = 500.
        let s = FuzzyMatcher.scoreMultiWord("hello wor", in: "Hello World")
        XCTAssertEqual(s, 500)
    }

    func testMultiWord_threeTokensAllMatch() {
        let s = FuzzyMatcher.scoreMultiWord("the quick fox", in: "The quick brown fox")
        XCTAssertGreaterThan(s, 0)
    }

    func testMultiWord_emptyQuery_returnsNonZero() {
        let s = FuzzyMatcher.scoreMultiWord("", in: "Hello World")
        XCTAssertGreaterThan(s, 0)
    }

    // MARK: - Edge cases

    func testEmptyToken_returnsZero() {
        XCTAssertEqual(FuzzyMatcher.score("", in: "Hello World"), 0)
    }

    func testEmptyText_returnsZero() {
        XCTAssertEqual(FuzzyMatcher.score("hello", in: ""), 0)
    }

    func testBothEmpty_returnsZero() {
        XCTAssertEqual(FuzzyMatcher.score("", in: ""), 0)
    }

    func testSingleCharMatch() {
        XCTAssertGreaterThan(FuzzyMatcher.score("h", in: "Hello"), 0)
    }

    func testTokenLongerThanText_returnsZero() {
        XCTAssertEqual(FuzzyMatcher.score("verylongtokentext", in: "short"), 0)
    }
}
