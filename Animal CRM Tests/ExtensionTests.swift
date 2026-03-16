//
//  ExtensionTests.swift
//  Animal CRM Tests
//
//  Tests for String.strippingHTML and Date.relativeFormatted.
//

import XCTest
@testable import Animal_CRM

// MARK: - String.strippingHTML

final class StringStrippingHTMLTests: XCTestCase {

    func test_removesBasicOpenCloseTag() {
        XCTAssertEqual("<p>Hello World</p>".strippingHTML, "Hello World")
    }

    func test_removesMultipleDifferentTags() {
        XCTAssertEqual("<strong>Bold</strong> and <em>italic</em>".strippingHTML, "Bold and italic")
    }

    func test_removesNestedTags() {
        XCTAssertEqual("<div><p>Nested <span>text</span></p></div>".strippingHTML, "Nested text")
    }

    func test_handlesSelfClosingBrTag() {
        XCTAssertEqual("One<br/>Two".strippingHTML, "OneTwo")
    }

    func test_handlesSelfClosingBrTagWithSpace() {
        XCTAssertEqual("One<br />Two".strippingHTML, "OneTwo")
    }

    func test_trimsLeadingAndTrailingWhitespace() {
        XCTAssertEqual("  <p>  content  </p>  ".strippingHTML, "content")
    }

    func test_plainText_returnedUnchanged() {
        XCTAssertEqual("No tags here".strippingHTML, "No tags here")
    }

    func test_emptyString_returnsEmpty() {
        XCTAssertEqual("".strippingHTML, "")
    }

    func test_onlyTags_returnsEmpty() {
        XCTAssertEqual("<html><body></body></html>".strippingHTML, "")
    }

    func test_tagWithAttributes() {
        XCTAssertEqual("<a href=\"https://example.com\">Click here</a>".strippingHTML, "Click here")
    }

    func test_tagWithClassAttribute() {
        XCTAssertEqual("<div class=\"container\">Content</div>".strippingHTML, "Content")
    }

    func test_realWorldEmailBody() {
        let html = "<div>Hi <strong>Bob</strong>,</div>"
        XCTAssertEqual(html.strippingHTML, "Hi Bob,")
    }
}

// MARK: - Date.relativeFormatted

final class DateRelativeFormattedTests: XCTestCase {

    // MARK: Today

    func test_today_containsAmOrPm() {
        let result = Date().relativeFormatted
        let upper = result.uppercased()
        XCTAssertTrue(upper.contains("AM") || upper.contains("PM"), "Expected AM/PM in '\(result)'")
    }

    func test_today_doesNotContainSlash() {
        // "M/d/yy" format is only for dates older than yesterday
        XCTAssertFalse(Date().relativeFormatted.contains("/"))
    }

    func test_today_doesNotReturnYesterday() {
        XCTAssertNotEqual(Date().relativeFormatted, "Yesterday")
    }

    // MARK: Yesterday

    func test_yesterday_returnsYesterdayString() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(yesterday.relativeFormatted, "Yesterday")
    }

    // MARK: Older dates

    func test_twoDaysAgo_containsSlash() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertTrue(twoDaysAgo.relativeFormatted.contains("/"))
    }

    func test_twoWeeksAgo_containsSlash() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let result = twoWeeksAgo.relativeFormatted
        XCTAssertTrue(result.contains("/"))
        XCTAssertNotEqual(result, "Yesterday")
    }

    func test_lastYear_containsSlash() {
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        XCTAssertTrue(lastYear.relativeFormatted.contains("/"))
    }

    // MARK: Format checks

    func test_today_matchesTimeFormat() {
        // "h:mm a" should produce strings like "9:30 AM" or "12:05 PM"
        let result = Date().relativeFormatted
        // Must be non-empty and not a date string
        XCTAssertFalse(result.isEmpty)
        XCTAssertFalse(result.contains("-")) // not ISO format
    }

    func test_oldDate_shortFormat_hasTwoSlashes() {
        // "M/d/yy" has two slashes: month/day/year
        let old = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let slashCount = old.relativeFormatted.filter { $0 == "/" }.count
        XCTAssertEqual(slashCount, 2)
    }
}
