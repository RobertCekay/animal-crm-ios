//
//  ModelsTests.swift
//  Animal CRM Tests
//
//  Tests for all model computed properties and helpers.
//  Mirrors RSpec model specs — no networking, pure logic.
//

import XCTest
@testable import Animal_CRM

// MARK: - Conversation

final class ConversationModelTests: XCTestCase {

    // MARK: Helpers

    private func make(
        id: Int = 1,
        platform: String = "sms",
        leadId: Int? = 42,
        leadName: String? = "John Doe",
        contactNumber: String? = "+15551234567",
        snippet: String? = "Hello",
        unreadCount: Int = 0,
        lastMessageAt: Date? = nil
    ) -> Conversation {
        Conversation(id: id, platform: platform, leadId: leadId, leadName: leadName,
                     contactNumber: contactNumber, snippet: snippet,
                     unreadCount: unreadCount, lastMessageAt: lastMessageAt)
    }

    // MARK: displayName

    func test_displayName_usesLeadName_whenPresent() {
        XCTAssertEqual(make(leadName: "Alice Smith").displayName, "Alice Smith")
    }

    func test_displayName_ignoresEmptyLeadName_fallsBackToContactNumber() {
        XCTAssertEqual(make(leadName: "", contactNumber: "+15559876543").displayName, "+15559876543")
    }

    func test_displayName_fallsBackToContactNumber_whenLeadNameNil() {
        XCTAssertEqual(make(leadName: nil, contactNumber: "+15559876543").displayName, "+15559876543")
    }

    func test_displayName_returnsUnknown_whenBothNil() {
        XCTAssertEqual(make(leadName: nil, contactNumber: nil).displayName, "Unknown")
    }

    // MARK: Platform flags

    func test_isSms_trueForSms() {
        XCTAssertTrue(make(platform: "sms").isSms)
        XCTAssertFalse(make(platform: "sms").isEmail)
    }

    func test_isEmail_trueForEmail() {
        XCTAssertTrue(make(platform: "email").isEmail)
        XCTAssertFalse(make(platform: "email").isSms)
    }

    // MARK: Initials

    func test_initials_firstLetterUppercased() {
        XCTAssertEqual(make(leadName: "bob jones").initials, "B")
    }

    func test_initials_fromContactNumber_whenNoLeadName() {
        XCTAssertEqual(make(leadName: nil, contactNumber: "+1555").initials, "+")
    }

    // MARK: unreadCount mutability

    func test_unreadCount_isMutable() {
        var c = make(unreadCount: 5)
        c.unreadCount = 0
        XCTAssertEqual(c.unreadCount, 0)
    }

    func test_unreadCount_canBeIncrementedInPlace() {
        var c = make(unreadCount: 2)
        c.unreadCount += 3
        XCTAssertEqual(c.unreadCount, 5)
    }
}

// MARK: - LeadMessage

final class LeadMessageTests: XCTestCase {

    private func make(
        type: MessageType = .sms,
        direction: String = "outbound",
        body: String? = "Hello",
        subject: String? = nil,
        status: String? = "sent",
        duration: String? = nil,
        number: String? = nil,
        sentAt: Date? = nil,
        startedAt: Date? = nil,
        read: Bool? = true
    ) -> LeadMessage {
        LeadMessage(type: type, direction: direction, body: body, subject: subject,
                    status: status, duration: duration, number: number,
                    sentAt: sentAt, startedAt: startedAt, read: read)
    }

    // MARK: isOutbound

    func test_isOutbound_trueForOutbound() {
        XCTAssertTrue(make(direction: "outbound").isOutbound)
    }

    func test_isOutbound_falseForInbound() {
        XCTAssertFalse(make(direction: "inbound").isOutbound)
    }

    // MARK: id

    func test_id_prefixedWithMessageType() {
        let msg = make(type: .email, sentAt: Date(timeIntervalSince1970: 1_000_000))
        XCTAssertTrue(msg.id.hasPrefix("email-"))
    }

    func test_id_smsPrefix() {
        let msg = make(type: .sms, sentAt: Date(timeIntervalSince1970: 1_000_000))
        XCTAssertTrue(msg.id.hasPrefix("sms-"))
    }

    func test_id_callPrefix() {
        let msg = make(type: .call, startedAt: Date(timeIntervalSince1970: 999))
        XCTAssertTrue(msg.id.hasPrefix("call-"))
    }

    func test_id_containsSentAtTimestamp() {
        let ts: TimeInterval = 1_234_567.0
        let msg = make(sentAt: Date(timeIntervalSince1970: ts))
        XCTAssertTrue(msg.id.contains("1234567.0"))
    }

    func test_id_fallsBackToStartedAt_whenSentAtNil() {
        let ts: TimeInterval = 9_876_543.0
        let msg = make(type: .call, sentAt: nil, startedAt: Date(timeIntervalSince1970: ts))
        XCTAssertTrue(msg.id.contains("9876543.0"))
    }
}

// MARK: - LeadThread

final class LeadThreadTests: XCTestCase {

    private func make(id: Int = 1, name: String = "Jane Doe", phone: String? = "+15551234567") -> LeadThread {
        LeadThread(id: id, name: name, phone: phone, snippet: "Test", unreadCount: 2, lastMessageAt: Date())
    }

    func test_initials_firstLetterUppercased() {
        XCTAssertEqual(make(name: "jane").initials, "J")
    }

    func test_initials_singleCharacter() {
        XCTAssertEqual(make(name: "Z").initials, "Z")
    }

    func test_lead_hasMatchingId() {
        XCTAssertEqual(make(id: 99).lead.id, 99)
    }

    func test_lead_hasMatchingName() {
        XCTAssertEqual(make(name: "Test User").lead.name, "Test User")
    }

    func test_lead_hasPhone() {
        XCTAssertEqual(make(phone: "+15551112222").lead.phone, "+15551112222")
    }

    func test_lead_hasNilEmail() {
        // Minimal Lead built from LeadThread always has nil email
        XCTAssertNil(make().lead.email)
    }
}

// MARK: - MessageChannel

final class MessageChannelTests: XCTestCase {

    func test_emailLabel() {
        XCTAssertEqual(MessageChannel.email.label, "Email")
    }

    func test_smsLabel() {
        XCTAssertEqual(MessageChannel.sms.label, "Text Message")
    }

    func test_emailIcon_isEnvelope() {
        XCTAssertEqual(MessageChannel.email.icon, "envelope")
    }

    func test_smsIcon_isMessage() {
        XCTAssertEqual(MessageChannel.sms.icon, "message")
    }

    func test_rawValues() {
        XCTAssertEqual(MessageChannel.email.rawValue, "email")
        XCTAssertEqual(MessageChannel.sms.rawValue, "sms")
    }

    func test_caseIterable_hasTwoCases() {
        XCTAssertEqual(MessageChannel.allCases.count, 2)
    }
}

// MARK: - JobStatus

final class JobStatusTests: XCTestCase {

    func test_allDisplayNames() {
        XCTAssertEqual(JobStatus.draft.displayName,      "Draft")
        XCTAssertEqual(JobStatus.scheduled.displayName,  "Scheduled")
        XCTAssertEqual(JobStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(JobStatus.completed.displayName,  "Completed")
        XCTAssertEqual(JobStatus.cancelled.displayName,  "Cancelled")
    }

    func test_rawValues_matchRailsStrings() {
        XCTAssertEqual(JobStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(JobStatus.draft.rawValue,      "draft")
        XCTAssertEqual(JobStatus.scheduled.rawValue,  "scheduled")
        XCTAssertEqual(JobStatus.completed.rawValue,  "completed")
        XCTAssertEqual(JobStatus.cancelled.rawValue,  "cancelled")
    }

    func test_allCases_hasFiveCases() {
        XCTAssertEqual(JobStatus.allCases.count, 5)
    }
}

// MARK: - MessageType

final class MessageTypeTests: XCTestCase {

    func test_rawValues() {
        XCTAssertEqual(MessageType.email.rawValue, "email")
        XCTAssertEqual(MessageType.sms.rawValue,   "sms")
        XCTAssertEqual(MessageType.call.rawValue,  "call")
    }
}
