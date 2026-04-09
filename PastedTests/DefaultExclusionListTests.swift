import XCTest
@testable import Pasted

/// Tests for DefaultExclusionList (spec 004).
final class DefaultExclusionListTests: XCTestCase {

    // MARK: - Count

    func testListHasNineEntries() {
        XCTAssertEqual(DefaultExclusionList.entries.count, 9,
                       "Default exclusion list should contain exactly 9 entries")
    }

    // MARK: - Format

    func testAllBundleIDsAreReverseDNS() {
        for entry in DefaultExclusionList.entries {
            let dotCount = entry.bundleID.filter { $0 == "." }.count
            XCTAssertGreaterThanOrEqual(dotCount, 2,
                "Bundle ID '\(entry.bundleID)' should be reverse-DNS format (at least 2 dots)")
        }
    }

    // MARK: - Uniqueness

    func testNoDuplicateBundleIdentifiers() {
        let ids = DefaultExclusionList.entries.map(\.bundleID)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count,
                       "Bundle identifiers should have no duplicates")
    }

    func testBundleIdentifiersSetMatchesEntries() {
        XCTAssertEqual(DefaultExclusionList.bundleIdentifiers.count,
                       DefaultExclusionList.entries.count,
                       "bundleIdentifiers set count should match entries count")
    }

    // MARK: - Specific Entries

    func testContains1Password8() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("com.1password.1password"))
    }

    func testContains1Password7() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("com.agilebits.onepassword7"))
    }

    func testContainsBitwarden() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("com.bitwarden.desktop"))
    }

    func testContainsLastPass() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("com.lastpass.LastPass"))
    }

    func testContainsKeePassXC() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("org.keepassxc.keepassxc"))
    }

    func testContainsDashlane() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("com.getdashlane.dashlane"))
    }

    func testContainsKeychainAccess() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("com.apple.keychainaccess"))
    }

    func testContainsEnpass() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("in.sinew.Enpass-Desktop"))
    }

    func testContainsSecrets() {
        XCTAssertTrue(DefaultExclusionList.bundleIdentifiers.contains("com.nickvdp.Secrets"))
    }
}
