//
//  JSONDecodingTests.swift
//  Animal CRM Tests
//
//  Tests for JSON decoding of all API response models.
//  Verifies the custom ISO 8601 date decoder handles Rails' fractional-second
//  timestamps (e.g. "2026-03-16T18:00:00.000Z") and plain timestamps both work.
//  Analogous to RSpec serializer specs.
//

import XCTest
@testable import Animal_CRM

// MARK: - Shared Decoder

/// Replicates the private decoder inside APIService.
private let apiDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let withoutFractional = ISO8601DateFormatter()
    withoutFractional.formatOptions = [.withInternetDateTime]
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        if let date = withFractional.date(from: str)   { return date }
        if let date = withoutFractional.date(from: str) { return date }
        throw DecodingError.dataCorruptedError(
            in: container, debugDescription: "Cannot decode date: \(str)")
    }
    return decoder
}()

private func json(_ string: String) -> Data { Data(string.utf8) }
private func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
    try apiDecoder.decode(type, from: Data(string.utf8))
}

// MARK: - Date Decoding

final class DateDecodingTests: XCTestCase {

    func test_fractionalSecondsDate_decodesSuccessfully() throws {
        let c = try decode(Conversation.self, from: """
        {"id":1,"platform":"sms","unread_count":0,"last_message_at":"2026-03-16T18:00:00.000Z"}
        """)
        XCTAssertNotNil(c.lastMessageAt)
    }

    func test_noFractionalSecondsDate_decodesSuccessfully() throws {
        let c = try decode(Conversation.self, from: """
        {"id":1,"platform":"sms","unread_count":0,"last_message_at":"2026-03-16T18:00:00Z"}
        """)
        XCTAssertNotNil(c.lastMessageAt)
    }

    func test_nullDate_decodesAsNil() throws {
        let c = try decode(Conversation.self, from: """
        {"id":1,"platform":"email","unread_count":2,"last_message_at":null}
        """)
        XCTAssertNil(c.lastMessageAt)
    }

    func test_fractionalAndNoFractional_produceSameInstant() throws {
        let withFrac    = try decode(Conversation.self, from: """
            {"id":1,"platform":"sms","unread_count":0,"last_message_at":"2026-03-16T18:00:00.000Z"}
            """)
        let withoutFrac = try decode(Conversation.self, from: """
            {"id":1,"platform":"sms","unread_count":0,"last_message_at":"2026-03-16T18:00:00Z"}
            """)
        XCTAssertEqual(withFrac.lastMessageAt?.timeIntervalSince1970,
                       withoutFrac.lastMessageAt?.timeIntervalSince1970)
    }
}

// MARK: - Conversation Decoding

final class ConversationDecodingTests: XCTestCase {

    func test_fullConversation_decodesAllSnakeCaseKeys() throws {
        let c = try decode(Conversation.self, from: """
        {
          "id": 42,
          "platform": "sms",
          "lead_id": 7,
          "lead_name": "Alice",
          "contact_number": "+15551234567",
          "snippet": "Hey!",
          "unread_count": 3,
          "last_message_at": null
        }
        """)
        XCTAssertEqual(c.id,            42)
        XCTAssertEqual(c.platform,      "sms")
        XCTAssertEqual(c.leadId,        7)
        XCTAssertEqual(c.leadName,      "Alice")
        XCTAssertEqual(c.contactNumber, "+15551234567")
        XCTAssertEqual(c.snippet,       "Hey!")
        XCTAssertEqual(c.unreadCount,   3)
    }

    func test_conversation_withNullOptionals_decodesSuccessfully() throws {
        let c = try decode(Conversation.self, from: """
        {"id":5,"platform":"email","unread_count":0,"lead_id":null,"lead_name":null,
         "contact_number":null,"snippet":null,"last_message_at":null}
        """)
        XCTAssertNil(c.leadId)
        XCTAssertNil(c.leadName)
        XCTAssertNil(c.contactNumber)
        XCTAssertNil(c.snippet)
    }

    func test_conversationsResponse_decodesList() throws {
        let r = try decode(ConversationsResponse.self, from: """
        {
          "conversations": [
            {"id":1,"platform":"sms","unread_count":1},
            {"id":2,"platform":"email","unread_count":0}
          ]
        }
        """)
        XCTAssertEqual(r.conversations.count, 2)
        XCTAssertEqual(r.conversations[0].id, 1)
        XCTAssertEqual(r.conversations[1].id, 2)
    }

    func test_conversationsResponse_withMeta_decodesAllFields() throws {
        let r = try decode(ConversationsResponse.self, from: """
        {
          "conversations": [],
          "meta": {"page":2,"per_page":25,"total":60,"total_pages":3}
        }
        """)
        XCTAssertEqual(r.meta?.page,       2)
        XCTAssertEqual(r.meta?.perPage,    25)
        XCTAssertEqual(r.meta?.total,      60)
        XCTAssertEqual(r.meta?.totalPages, 3)
    }

    func test_conversationsResponse_withoutMeta_metaIsNil() throws {
        let r = try decode(ConversationsResponse.self, from: """
        {"conversations":[]}
        """)
        XCTAssertNil(r.meta)
    }
}

// MARK: - LeadMessage Decoding

final class LeadMessageDecodingTests: XCTestCase {

    func test_smsMessage_decodesType() throws {
        let m = try decode(LeadMessage.self, from: """
        {"type":"sms","direction":"inbound","status":null}
        """)
        XCTAssertEqual(m.type, .sms)
        XCTAssertFalse(m.isOutbound)
    }

    func test_emailMessage_decodesType() throws {
        let m = try decode(LeadMessage.self, from: """
        {"type":"email","direction":"outbound","status":"sent"}
        """)
        XCTAssertEqual(m.type, .email)
        XCTAssertTrue(m.isOutbound)
    }

    func test_callMessage_decodesType() throws {
        let m = try decode(LeadMessage.self, from: """
        {"type":"call","direction":"inbound","status":"completed",
         "started_at":"2026-03-16T14:30:00Z"}
        """)
        XCTAssertEqual(m.type, .call)
        XCTAssertNotNil(m.startedAt)
    }

    func test_smsMessage_withFractionalSentAt() throws {
        let m = try decode(LeadMessage.self, from: """
        {"type":"sms","direction":"outbound","status":"delivered",
         "sent_at":"2026-03-16T18:05:32.123Z"}
        """)
        XCTAssertNotNil(m.sentAt)
        XCTAssertEqual(m.status, "delivered")
    }

    func test_emailMessage_decodesSubject() throws {
        let m = try decode(LeadMessage.self, from: """
        {"type":"email","direction":"outbound","subject":"Re: Your estimate","body":"<p>Hi</p>"}
        """)
        XCTAssertEqual(m.subject, "Re: Your estimate")
        XCTAssertEqual(m.body,    "<p>Hi</p>")
    }
}

// MARK: - SendMessageResponse Decoding

final class SendMessageResponseDecodingTests: XCTestCase {

    func test_minimalResponse_okAndChannelAbsent() throws {
        // Rails may omit ok/channel — they must be optional or decode fails
        let r = try decode(SendMessageResponse.self, from: """
        {
          "message": {"type":"sms","direction":"outbound","status":"sent",
                      "sent_at":"2026-03-16T18:00:00.000Z"}
        }
        """)
        XCTAssertNil(r.ok)
        XCTAssertNil(r.channel)
        XCTAssertEqual(r.message.status, "sent")
    }

    func test_fullResponse_decodesOkAndChannel() throws {
        let r = try decode(SendMessageResponse.self, from: """
        {
          "ok": true,
          "channel": "sms",
          "message": {"type":"sms","direction":"outbound","status":"delivered",
                      "sent_at":"2026-03-16T18:00:00Z"}
        }
        """)
        XCTAssertEqual(r.ok,      true)
        XCTAssertEqual(r.channel, "sms")
        XCTAssertEqual(r.message.status, "delivered")
    }

    func test_emailChannel_decodesCorrectly() throws {
        let r = try decode(SendMessageResponse.self, from: """
        {
          "ok": true,
          "channel": "email",
          "message": {"type":"email","direction":"outbound","subject":"Test",
                      "body":"Hello","status":"sent"}
        }
        """)
        XCTAssertEqual(r.channel, "email")
        XCTAssertEqual(r.message.type, .email)
    }
}

// MARK: - PhoneLine Decoding

final class PhoneLineDecodingTests: XCTestCase {

    func test_decodesSnakeCaseKeys() throws {
        let line = try decode(PhoneLine.self, from: """
        {"id":5,"display_name":"Office Line","phone_number":"+15559990000"}
        """)
        XCTAssertEqual(line.id,          5)
        XCTAssertEqual(line.displayName, "Office Line")
        XCTAssertEqual(line.phoneNumber, "+15559990000")
    }

    func test_decodesMultiplePhoneLines() throws {
        struct PhoneLinesResponse: Decodable { let phoneLines: [PhoneLine] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let r = try decoder.decode(PhoneLinesResponse.self, from: json("""
        {"phone_lines":[
          {"id":1,"display_name":"Main","phone_number":"+15550001111"},
          {"id":2,"display_name":"Sales","phone_number":"+15550002222"}
        ]}
        """))
        XCTAssertEqual(r.phoneLines.count, 2)
        XCTAssertEqual(r.phoneLines[0].id, 1)
        XCTAssertEqual(r.phoneLines[1].id, 2)
    }
}

// MARK: - LeadMessagesResponse Decoding

final class LeadMessagesResponseDecodingTests: XCTestCase {

    func test_decodesCanEmailAndCanSms() throws {
        let r = try decode(LeadMessagesResponse.self, from: """
        {
          "messages": [],
          "can_email": true,
          "can_sms": false,
          "lead_email": "alice@example.com",
          "lead_phone": null
        }
        """)
        XCTAssertTrue(r.canEmail)
        XCTAssertFalse(r.canSms)
        XCTAssertEqual(r.leadEmail, "alice@example.com")
        XCTAssertNil(r.leadPhone)
    }

    func test_decodesWithMessages() throws {
        let r = try decode(LeadMessagesResponse.self, from: """
        {
          "messages": [
            {"type":"sms","direction":"inbound","status":"delivered",
             "sent_at":"2026-03-16T10:00:00Z"},
            {"type":"email","direction":"outbound","status":"sent",
             "sent_at":"2026-03-16T11:00:00Z"}
          ],
          "can_email": true,
          "can_sms": true
        }
        """)
        XCTAssertEqual(r.messages.count, 2)
        XCTAssertEqual(r.messages[0].type, .sms)
        XCTAssertEqual(r.messages[1].type, .email)
    }
}
