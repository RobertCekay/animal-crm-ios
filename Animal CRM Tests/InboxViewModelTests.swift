//
//  InboxViewModelTests.swift
//  Animal CRM Tests
//
//  Tests for InboxViewModel's lead-grouping logic, sorting, unread counting,
//  and optimistic badge clearing. Analogous to RSpec controller/service specs —
//  no networking, conversations are set directly on the view model.
//

import XCTest
@testable import Animal_CRM

@MainActor
final class InboxViewModelTests: XCTestCase {

    var vm: InboxViewModel!

    override func setUp() {
        super.setUp()
        vm = InboxViewModel()
        vm.conversations = [] // start clean
    }

    override func tearDown() {
        vm.stopPolling()
        vm = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeConversation(
        id: Int,
        platform: String = "sms",
        leadId: Int? = nil,
        leadName: String? = nil,
        contactNumber: String? = nil,
        snippet: String? = nil,
        unreadCount: Int = 0,
        lastMessageAt: Date? = nil
    ) -> Conversation {
        Conversation(id: id, platform: platform, leadId: leadId, leadName: leadName,
                     contactNumber: contactNumber, snippet: snippet,
                     unreadCount: unreadCount, lastMessageAt: lastMessageAt)
    }

    // MARK: - Empty state

    func test_leadThreads_empty_whenNoConversations() {
        vm.conversations = []
        XCTAssertTrue(vm.leadThreads.isEmpty)
    }

    func test_unreadCount_zero_whenNoConversations() {
        vm.conversations = []
        XCTAssertEqual(vm.unreadCount, 0)
    }

    // MARK: - Lead grouping

    func test_groupsSmsAndEmail_underSameLeadId() {
        let sms   = makeConversation(id: 1, platform: "sms",   leadId: 42, leadName: "Alice")
        let email = makeConversation(id: 2, platform: "email", leadId: 42, leadName: "Alice")
        vm.conversations = [sms, email]

        XCTAssertEqual(vm.leadThreads.count, 1)
        XCTAssertEqual(vm.leadThreads.first?.id, 42)
    }

    func test_separateLeadIds_produceSeparateRows() {
        let c1 = makeConversation(id: 1, leadId: 10, leadName: "Alice")
        let c2 = makeConversation(id: 2, leadId: 20, leadName: "Bob")
        vm.conversations = [c1, c2]

        XCTAssertEqual(vm.leadThreads.count, 2)
    }

    func test_threeConversations_twoLeads_producesTwoRows() {
        let sms   = makeConversation(id: 1, platform: "sms",   leadId: 42)
        let email = makeConversation(id: 2, platform: "email", leadId: 42)
        let other = makeConversation(id: 3, leadId: 99)
        vm.conversations = [sms, email, other]

        XCTAssertEqual(vm.leadThreads.count, 2)
    }

    // MARK: - Unread count aggregation

    func test_aggregatesUnreadCount_acrossChannels() {
        let sms   = makeConversation(id: 1, platform: "sms",   leadId: 42, unreadCount: 3)
        let email = makeConversation(id: 2, platform: "email", leadId: 42, unreadCount: 2)
        vm.conversations = [sms, email]

        XCTAssertEqual(vm.leadThreads.first?.unreadCount, 5)
    }

    func test_unreadCount_tabBadge_countsLeadsNotMessages() {
        // Two channels with unread for the same lead = 1 unread lead
        let sms   = makeConversation(id: 1, platform: "sms",   leadId: 42, unreadCount: 3)
        let email = makeConversation(id: 2, platform: "email", leadId: 42, unreadCount: 2)
        vm.conversations = [sms, email]

        XCTAssertEqual(vm.unreadCount, 1)
    }

    func test_unreadCount_tabBadge_countsMultipleUnreadLeads() {
        let c1 = makeConversation(id: 1, leadId: 10, unreadCount: 2)
        let c2 = makeConversation(id: 2, leadId: 20, unreadCount: 0)
        let c3 = makeConversation(id: 3, leadId: 30, unreadCount: 1)
        vm.conversations = [c1, c2, c3]

        XCTAssertEqual(vm.unreadCount, 2) // leads 10 and 30 have unread
    }

    func test_unreadCount_zero_whenAllConversationsRead() {
        let c1 = makeConversation(id: 1, leadId: 10, unreadCount: 0)
        let c2 = makeConversation(id: 2, leadId: 20, unreadCount: 0)
        vm.conversations = [c1, c2]

        XCTAssertEqual(vm.unreadCount, 0)
    }

    // MARK: - Snippet selection (most recent)

    func test_usesSnippet_fromMostRecentConversation() {
        let older = makeConversation(id: 1, leadId: 42, snippet: "Old message",
                                     lastMessageAt: Date(timeIntervalSinceNow: -3600))
        let newer = makeConversation(id: 2, leadId: 42, snippet: "New message",
                                     lastMessageAt: Date(timeIntervalSinceNow: -10))
        vm.conversations = [older, newer]

        XCTAssertEqual(vm.leadThreads.first?.snippet, "New message")
    }

    func test_usesLastMessageAt_fromMostRecentConversation() {
        let recentDate = Date(timeIntervalSinceNow: -10)
        let olderDate  = Date(timeIntervalSinceNow: -3600)
        let older = makeConversation(id: 1, leadId: 42, lastMessageAt: olderDate)
        let newer = makeConversation(id: 2, leadId: 42, lastMessageAt: recentDate)
        vm.conversations = [older, newer]

        XCTAssertEqual(vm.leadThreads.first?.lastMessageAt, recentDate)
    }

    // MARK: - Phone number on thread

    func test_phone_setFromSmsConversation_notEmail() {
        let sms   = makeConversation(id: 1, platform: "sms",   leadId: 42, contactNumber: "+15551112222")
        let email = makeConversation(id: 2, platform: "email", leadId: 42, contactNumber: nil)
        vm.conversations = [sms, email]

        XCTAssertEqual(vm.leadThreads.first?.phone, "+15551112222")
    }

    func test_phone_nilWhenNoSmsConversation() {
        let email = makeConversation(id: 1, platform: "email", leadId: 42, contactNumber: nil)
        vm.conversations = [email]

        XCTAssertNil(vm.leadThreads.first?.phone)
    }

    // MARK: - Orphan conversations (no leadId)

    func test_orphan_getsNegativeId() {
        let orphan = makeConversation(id: 99, leadId: nil, leadName: "Orphan User")
        vm.conversations = [orphan]

        XCTAssertEqual(vm.leadThreads.count, 1)
        XCTAssertEqual(vm.leadThreads.first?.id, -99)
    }

    func test_multipleOrphans_eachGetSeparateRow() {
        let o1 = makeConversation(id: 10, leadId: nil)
        let o2 = makeConversation(id: 20, leadId: nil)
        vm.conversations = [o1, o2]

        XCTAssertEqual(vm.leadThreads.count, 2)
        let ids = Set(vm.leadThreads.map(\.id))
        XCTAssertEqual(ids, [-10, -20])
    }

    func test_orphanAndGrouped_producesCorrectRowCount() {
        let grouped = makeConversation(id: 1, leadId: 42, leadName: "Alice")
        let orphan  = makeConversation(id: 2, leadId: nil)
        vm.conversations = [grouped, orphan]

        XCTAssertEqual(vm.leadThreads.count, 2)
    }

    // MARK: - Sorting (newest first)

    func test_sortedNewestFirst() {
        let old = makeConversation(id: 1, leadId: 10, lastMessageAt: Date(timeIntervalSinceNow: -7200))
        let new = makeConversation(id: 2, leadId: 20, lastMessageAt: Date(timeIntervalSinceNow: -10))
        vm.conversations = [old, new]

        XCTAssertEqual(vm.leadThreads.first?.id, 20)
        XCTAssertEqual(vm.leadThreads.last?.id,  10)
    }

    func test_nilLastMessageAt_sortedToBottom() {
        let withDate    = makeConversation(id: 1, leadId: 10, lastMessageAt: Date(timeIntervalSinceNow: -100))
        let withoutDate = makeConversation(id: 2, leadId: 20, lastMessageAt: nil)
        vm.conversations = [withDate, withoutDate]

        XCTAssertEqual(vm.leadThreads.first?.id, 10)
        XCTAssertEqual(vm.leadThreads.last?.id,  20)
    }

    func test_sortingStable_withThreeLeads() {
        let t1 = makeConversation(id: 1, leadId: 10, lastMessageAt: Date(timeIntervalSinceNow: -300))
        let t2 = makeConversation(id: 2, leadId: 20, lastMessageAt: Date(timeIntervalSinceNow: -100))
        let t3 = makeConversation(id: 3, leadId: 30, lastMessageAt: Date(timeIntervalSinceNow: -500))
        vm.conversations = [t3, t1, t2]

        let ids = vm.leadThreads.map(\.id)
        XCTAssertEqual(ids, [20, 10, 30])
    }

    // MARK: - Optimistic unread clearing

    func test_optimisticClear_zeroesUnreadForSpecificLead() {
        let sms   = makeConversation(id: 1, platform: "sms",   leadId: 42, unreadCount: 5)
        let email = makeConversation(id: 2, platform: "email", leadId: 42, unreadCount: 3)
        let other = makeConversation(id: 3, leadId: 99, unreadCount: 2)
        vm.conversations = [sms, email, other]

        // Simulate what the NotificationCenter observer does
        for i in vm.conversations.indices where vm.conversations[i].leadId == 42 {
            vm.conversations[i].unreadCount = 0
        }

        XCTAssertEqual(vm.leadThreads.first(where: { $0.id == 42 })?.unreadCount, 0)
        XCTAssertEqual(vm.leadThreads.first(where: { $0.id == 99 })?.unreadCount, 2)
    }

    func test_optimisticClear_reducesTabBadge_immediately() {
        let c1 = makeConversation(id: 1, leadId: 42, unreadCount: 3)
        let c2 = makeConversation(id: 2, leadId: 99, unreadCount: 1)
        vm.conversations = [c1, c2]
        XCTAssertEqual(vm.unreadCount, 2)

        // Open lead 42 — zero it out
        for i in vm.conversations.indices where vm.conversations[i].leadId == 42 {
            vm.conversations[i].unreadCount = 0
        }

        XCTAssertEqual(vm.unreadCount, 1) // only lead 99 remains
    }

    func test_optimisticClear_doesNotAffectOtherLeads() {
        let c1 = makeConversation(id: 1, leadId: 10, unreadCount: 4)
        let c2 = makeConversation(id: 2, leadId: 20, unreadCount: 7)
        vm.conversations = [c1, c2]

        for i in vm.conversations.indices where vm.conversations[i].leadId == 10 {
            vm.conversations[i].unreadCount = 0
        }

        XCTAssertEqual(vm.leadThreads.first(where: { $0.id == 20 })?.unreadCount, 7)
    }

    // MARK: - leadThread(forConversationId:platform:)

    func test_leadThread_found_byConversationId_andPlatform() {
        let c = makeConversation(id: 7, platform: "sms", leadId: 55, leadName: "Bob")
        vm.conversations = [c]

        let thread = vm.leadThread(forConversationId: 7, platform: "sms")
        XCTAssertNotNil(thread)
        XCTAssertEqual(thread?.id, 55)
    }

    func test_leadThread_notFound_wrongPlatform() {
        let c = makeConversation(id: 7, platform: "sms", leadId: 55)
        vm.conversations = [c]

        XCTAssertNil(vm.leadThread(forConversationId: 7, platform: "email"))
    }

    func test_leadThread_notFound_wrongConversationId() {
        let c = makeConversation(id: 7, platform: "sms", leadId: 55)
        vm.conversations = [c]

        XCTAssertNil(vm.leadThread(forConversationId: 999, platform: "sms"))
    }

    func test_leadThread_notFound_whenNoLeadId() {
        let c = makeConversation(id: 7, platform: "sms", leadId: nil)
        vm.conversations = [c]

        XCTAssertNil(vm.leadThread(forConversationId: 7, platform: "sms"))
    }
}
