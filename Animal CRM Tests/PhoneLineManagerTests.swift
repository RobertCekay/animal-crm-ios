//
//  PhoneLineManagerTests.swift
//  Animal CRM Tests
//
//  Tests for PhoneLineManager's synchronous selection and persistence behavior.
//  Network-dependent load() is excluded (that belongs in integration tests).
//  Analogous to RSpec service-object specs covering pure business logic.
//

import XCTest
@testable import Animal_CRM

@MainActor
final class PhoneLineManagerTests: XCTestCase {

    private let userDefaultsKey = "selected_phone_line_id"

    override func setUp() {
        super.setUp()
        // Reset singleton to a clean baseline before each test
        PhoneLineManager.shared.phoneLines = []
        PhoneLineManager.shared.selectedLine = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    override func tearDown() {
        // Leave UserDefaults clean for other tests
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        super.tearDown()
    }

    // MARK: - Initial state

    func test_phoneLines_emptyAfterReset() {
        XCTAssertTrue(PhoneLineManager.shared.phoneLines.isEmpty)
    }

    func test_selectedLine_nilAfterReset() {
        XCTAssertNil(PhoneLineManager.shared.selectedLine)
    }

    // MARK: - select(_:)

    func test_select_updatesSelectedLine() {
        let line = PhoneLine(id: 1, displayName: "Main Line", phoneNumber: "+15551234567")
        PhoneLineManager.shared.select(line)

        XCTAssertEqual(PhoneLineManager.shared.selectedLine?.id, 1)
        XCTAssertEqual(PhoneLineManager.shared.selectedLine?.displayName, "Main Line")
        XCTAssertEqual(PhoneLineManager.shared.selectedLine?.phoneNumber, "+15551234567")
    }

    func test_select_persistsIdToUserDefaults() {
        let line = PhoneLine(id: 77, displayName: "Secondary", phoneNumber: "+15559876543")
        PhoneLineManager.shared.select(line)

        let saved = UserDefaults.standard.integer(forKey: userDefaultsKey)
        XCTAssertEqual(saved, 77)
    }

    func test_select_switchingLines_updatesSelection() {
        let lineA = PhoneLine(id: 1, displayName: "Line A", phoneNumber: "+15550000001")
        let lineB = PhoneLine(id: 2, displayName: "Line B", phoneNumber: "+15550000002")
        PhoneLineManager.shared.phoneLines = [lineA, lineB]

        PhoneLineManager.shared.select(lineA)
        XCTAssertEqual(PhoneLineManager.shared.selectedLine?.id, 1)

        PhoneLineManager.shared.select(lineB)
        XCTAssertEqual(PhoneLineManager.shared.selectedLine?.id, 2)
    }

    func test_select_switchingLines_updatesUserDefaults() {
        let lineA = PhoneLine(id: 10, displayName: "A", phoneNumber: "+1")
        let lineB = PhoneLine(id: 20, displayName: "B", phoneNumber: "+2")

        PhoneLineManager.shared.select(lineA)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: userDefaultsKey), 10)

        PhoneLineManager.shared.select(lineB)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: userDefaultsKey), 20)
    }

    // MARK: - phoneLines collection

    func test_settingPhoneLines_updatesCount() {
        PhoneLineManager.shared.phoneLines = [
            PhoneLine(id: 1, displayName: "A", phoneNumber: "+1"),
            PhoneLine(id: 2, displayName: "B", phoneNumber: "+2"),
            PhoneLine(id: 3, displayName: "C", phoneNumber: "+3")
        ]
        XCTAssertEqual(PhoneLineManager.shared.phoneLines.count, 3)
    }

    func test_clearingPhoneLines_emptiesCollection() {
        PhoneLineManager.shared.phoneLines = [
            PhoneLine(id: 1, displayName: "A", phoneNumber: "+1")
        ]
        PhoneLineManager.shared.phoneLines = []
        XCTAssertTrue(PhoneLineManager.shared.phoneLines.isEmpty)
    }
}
