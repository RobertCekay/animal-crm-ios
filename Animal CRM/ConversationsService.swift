//
//  ConversationsService.swift
//  Animal CRM
//
//  Thin service layer over APIService for the unified conversations inbox.
//

import Foundation

final class ConversationsService {
    static let shared = ConversationsService()
    private init() {}

    func fetchInbox(query: String? = nil) async throws -> [Conversation] {
        try await APIService.shared.fetchConversations(query: query)
    }

    func fetchMessages(id: Int, platform: String) async throws -> ConversationThread {
        try await APIService.shared.fetchConversationThread(id: id, platform: platform)
    }

    func reply(id: Int, platform: String, body: String, subject: String? = nil, phoneLineId: Int? = nil) async throws -> ConversationMessage? {
        try await APIService.shared.replyToConversation(id: id, platform: platform, body: body, subject: subject, phoneLineId: phoneLineId)
    }

    func markRead(id: Int, platform: String) async throws {
        try await APIService.shared.markConversationRead(id: id, platform: platform)
    }
}
