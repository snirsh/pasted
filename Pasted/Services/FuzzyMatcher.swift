import Foundation

/// Fuzzy text matching with 4 relevance tiers.
/// Used by SearchEngine to post-filter and rank clipboard items by text relevance.
struct FuzzyMatcher {

    /// Scores how well a single search token matches a text string.
    ///
    /// Tiers (checked in order, highest to lowest):
    /// - 1000: Token is an exact whole-word match in text
    /// - 500:  Token is a prefix of some word in text
    /// - 200:  Token appears as a substring anywhere in text (mid-word)
    /// - 50:   Token characters appear in order as a subsequence
    /// - 0:    No match
    static func score(_ token: String, in text: String) -> Int {
        guard !token.isEmpty, !text.isEmpty else { return 0 }

        let t = token.lowercased()
        let txt = text.lowercased()

        let words = txt.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Tier 1: Token is an entire word in the text
        for word in words where word == t {
            return 1000
        }

        // Tier 2: Token is a prefix of any word in the text
        for word in words where word.hasPrefix(t) {
            return 500
        }

        // Tier 3: Token appears as a substring anywhere (including mid-word)
        if txt.contains(t) {
            return 200
        }

        // Tier 4: Token characters appear in order as a scattered subsequence
        if isSubsequence(t, of: txt) {
            return 50
        }

        return 0
    }

    /// Scores a multi-word query against text using AND semantics.
    ///
    /// The query is split on whitespace. ALL tokens must match (score > 0).
    /// The overall score is the minimum token score — the weakest link.
    /// An empty or whitespace-only query scores 50 (matches everything).
    static func scoreMultiWord(_ query: String, in text: String) -> Int {
        let tokens = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return 50 }

        var minScore = Int.max
        for token in tokens {
            let s = score(token, in: text)
            if s == 0 { return 0 }
            minScore = min(minScore, s)
        }
        return minScore
    }

    // MARK: - Private

    /// Returns true if every character in `sub` appears in `str` in the same order.
    private static func isSubsequence(_ sub: String, of str: String) -> Bool {
        var subIdx = sub.startIndex
        for char in str {
            guard subIdx < sub.endIndex else { break }
            if char == sub[subIdx] {
                subIdx = sub.index(after: subIdx)
            }
        }
        return subIdx == sub.endIndex
    }
}
