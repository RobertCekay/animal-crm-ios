//
//  SMSInboxView.swift
//  Animal CRM
//
//  SMS conversations inbox
//

import SwiftUI

struct SMSInboxView: View {
    @EnvironmentObject var api: APIService
    @State private var conversations: [SmsConversation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            Group {
                if isLoading && conversations.isEmpty {
                    ProgressView("Loading messages...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No conversations yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(conversations) { conversation in
                        NavigationLink(destination: SMSThreadView(conversation: conversation)) {
                            ConversationRow(conversation: conversation)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Messages")
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
        .onAppear {
            Task { await load() }
            startPolling()
        }
        .onDisappear {
            pollingTask?.cancel()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await api.fetchSmsConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !Task.isCancelled { await load() }
            }
        }
    }
}

struct ConversationRow: View {
    let conversation: SmsConversation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(conversation.leadName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.leadName.isEmpty ? conversation.contactNumber : conversation.leadName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if let date = conversation.lastMessageAt {
                        Text(date.relativeFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Text(conversation.snippet ?? "No messages")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

extension Date {
    var relativeFormatted: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: self)
        } else if cal.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let f = DateFormatter()
            f.dateFormat = "M/d/yy"
            return f.string(from: self)
        }
    }
}

#Preview {
    SMSInboxView()
        .environmentObject(APIService.shared)
}
