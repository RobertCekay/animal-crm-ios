//
//  SMSThreadView.swift
//  Animal CRM
//
//  SMS conversation thread with chat bubbles and reply.
//  • Outbound messages: right-aligned purple bubble
//  • Inbound messages:  left-aligned gray bubble
//  • Polls every 20 seconds for new inbound messages
//  • Optimistic send: appends immediately, confirms/reverts on API response
//

import SwiftUI

struct SMSThreadView: View {
    let conversation: SmsConversation

    @EnvironmentObject var api: APIService
    @State private var messages: [SmsMessage] = []
    @State private var replyText = ""
    @State private var isSending = false
    @State private var isLoading = false
    @State private var sendError: String?
    @State private var pollingTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    /// Sentinel ID used for the optimistic message placeholder.
    private let optimisticId = Int.min

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // Send error (inline, above input bar)
            if let err = sendError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
            }

            Divider()

            // Reply bar
            HStack(spacing: 8) {
                TextField("Message", text: $replyText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($inputFocused)

                Button { send() } label: {
                    Image(systemName: isSending ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? Color(red: 0.58, green: 0.18, blue: 0.98) : .secondary)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading { ProgressView() }
            }
        }
        .onAppear {
            Task { await load() }
            startPolling()
        }
        .onDisappear {
            pollingTask?.cancel()
        }
    }

    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let thread = try await api.fetchSmsThread(conversationId: conversation.id)
            messages = thread.messages
        } catch { }
    }

    // MARK: - 20-second Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { break }
                await pollForNew()
            }
        }
    }

    private func pollForNew() async {
        guard let thread = try? await api.fetchSmsThread(conversationId: conversation.id) else { return }
        let existingIds = Set(messages.map(\.id))
        let newMessages = thread.messages.filter { !existingIds.contains($0.id) && $0.id != optimisticId }
        if !newMessages.isEmpty {
            messages.append(contentsOf: newMessages)
        }
    }

    // MARK: - Send (Optimistic)

    private func send() {
        let text = replyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        replyText = ""
        sendError = nil
        isSending = true

        // Append optimistic placeholder immediately
        let optimistic = SmsMessage(
            id: optimisticId,
            body: text,
            direction: "outbound",
            status: "sending",
            fromNumber: nil,
            toNumber: nil,
            read: true,
            sentAt: Date()
        )
        messages.append(optimistic)

        Task {
            defer { isSending = false }
            do {
                let sent = try await api.replySms(conversationId: conversation.id, body: text)
                messages.removeAll { $0.id == optimisticId }
                messages.append(sent)
            } catch {
                messages.removeAll { $0.id == optimisticId }
                replyText = text
                sendError = "Failed to send. Tap to retry."
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: SmsMessage

    private var isOutbound: Bool { message.direction == "outbound" }
    private static let outboundColor = Color(red: 0.58, green: 0.18, blue: 0.98)

    var body: some View {
        HStack {
            if isOutbound { Spacer(minLength: 60) }

            VStack(alignment: isOutbound ? .trailing : .leading, spacing: 3) {
                Text(message.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isOutbound ? Self.outboundColor : Color(.systemGray5))
                    .foregroundColor(isOutbound ? .white : .primary)
                    .clipShape(BubbleShape(isOutbound: isOutbound))

                HStack(spacing: 4) {
                    if let sentAt = message.sentAt {
                        Text(sentAt.relativeFormatted)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if isOutbound {
                        statusIcon(message.status)
                    }
                }
            }

            if !isOutbound { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: String?) -> some View {
        switch status {
        case "delivered":
            Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundColor(.green)
        case "failed":
            Image(systemName: "exclamationmark.circle.fill").font(.caption2).foregroundColor(.red)
        case "sent":
            Image(systemName: "checkmark.circle").font(.caption2).foregroundColor(.secondary)
        default:
            Image(systemName: "clock").font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isOutbound: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        let tail: CGFloat = 6
        var path = Path()

        if isOutbound {
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r - tail, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - tail, y: rect.minY + r),
                              control: CGPoint(x: rect.maxX - tail, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - tail, y: rect.maxY - r))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                              control: CGPoint(x: rect.maxX - tail, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                              control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                              control: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX + tail, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - r),
                              control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.minY),
                              control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + r + tail, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.minX + tail, y: rect.minY + r),
                              control: CGPoint(x: rect.minX + tail, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + tail, y: rect.maxY - r))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                              control: CGPoint(x: rect.minX + tail, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationView {
        SMSThreadView(conversation: SmsConversation(
            id: 1,
            contactNumber: "+15555551234",
            leadId: nil,
            leadName: "John Doe",
            snippet: "Hey!",
            unreadCount: 0,
            lastMessageAt: Date(),
            phoneLineId: nil,
            createdAt: Date()
        ))
        .environmentObject(APIService.shared)
    }
}
