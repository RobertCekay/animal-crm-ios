//
//  ThreadView.swift
//  Animal CRM
//
//  Unified conversation thread for SMS and Email.
//  • Outbound: right-aligned purple bubble
//  • Inbound:  left-aligned gray bubble
//  • Email bodies: HTML stripped to plain text; subject shown as label above bubble
//  • Phone icon in toolbar for SMS threads → CallManager
//  • Polls every 20 s for new messages
//  • Optimistic send with revert on failure
//

import SwiftUI

struct ThreadView: View {
    let conversation: Conversation

    @State private var messages: [ConversationMessage] = []
    @State private var isLoading = false
    @State private var replyText = ""
    @State private var emailSubject = ""
    @State private var showSubjectField = true
    @State private var isSending = false
    @State private var sendError: String?
    @State private var pollingTask: Task<Void, Never>?
    @State private var contactNumber: String?
    @State private var displayName: String = ""
    @State private var showPhoneLinePicker = false
    @ObservedObject private var phoneLineManager = PhoneLineManager.shared
    @FocusState private var inputFocused: Bool

    private let optimisticId = Int.min
    private static let outboundColor = Color(red: 0.58, green: 0.18, blue: 0.98)

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            ThreadBubble(message: msg, platform: conversation.platform)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in scrollToBottom(proxy) }
                .onAppear { scrollToBottom(proxy) }
            }

            // Send error
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
            VStack(spacing: 0) {
                // From: phone line row (SMS only, at least 1 line loaded)
                if conversation.isSms, let line = phoneLineManager.selectedLine {
                    fromRow(line: line, canPick: phoneLineManager.phoneLines.count > 1)
                    Divider().padding(.top, 6)
                }

                if conversation.isEmail && showSubjectField {
                    HStack {
                        Text("Subject:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Subject", text: $emailSubject)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    Divider().padding(.top, 6)
                }

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
                            .foregroundColor(canSend ? Self.outboundColor : .secondary)
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(displayName.isEmpty ? conversation.displayName : displayName)
                        .font(.headline)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if conversation.isSms, let number = contactNumber {
                    Button {
                        let name = displayName.isEmpty ? conversation.displayName : displayName
                        CallManager.shared.dial(to: number, displayName: name)
                    } label: {
                        Image(systemName: "phone.fill")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading { ProgressView().scaleEffect(0.8) }
            }
        }
        .onAppear {
            displayName = conversation.displayName
            contactNumber = conversation.contactNumber
            Task { await load() }
            startPolling()
        }
        .onDisappear { pollingTask?.cancel() }
    }

    // MARK: - Computed

    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    private var subtitle: String? {
        if conversation.isSms { return contactNumber ?? conversation.contactNumber }
        return nil
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let thread = try await ConversationsService.shared.fetchMessages(
                id: conversation.id, platform: conversation.platform
            )
            messages = thread.messages
            if let name = thread.leadName, !name.isEmpty { displayName = name }
            if let num = thread.contactNumber { contactNumber = num }

            // Pre-fill email subject
            if conversation.isEmail && emailSubject.isEmpty {
                let lastSubject = thread.messages.compactMap(\.subject).last
                emailSubject = lastSubject.map { "Re: \($0)" }
                    ?? conversation.snippet.map { "Re: \($0)" }
                    ?? ""
            }

            Task { try? await ConversationsService.shared.markRead(
                id: conversation.id, platform: conversation.platform
            )}
        } catch { }
    }

    // MARK: - Polling

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
        guard let thread = try? await ConversationsService.shared.fetchMessages(
            id: conversation.id, platform: conversation.platform
        ) else { return }
        let existing = Set(messages.map(\.id))
        let fresh = thread.messages.filter { !existing.contains($0.id) && $0.id != optimisticId }
        if !fresh.isEmpty { messages.append(contentsOf: fresh) }
    }

    // MARK: - Send

    private func send() {
        let text = replyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let subject = conversation.isEmail && showSubjectField ? emailSubject : nil
        replyText = ""
        sendError = nil
        isSending = true

        // Optimistic message
        let optimistic = ConversationMessage(
            id: optimisticId,
            type: conversation.platform,
            body: text,
            direction: "outbound",
            read: true,
            sentAt: Date(),
            fromNumber: nil, toNumber: nil, status: "sending",
            subject: subject, fromEmail: nil, toEmail: nil
        )
        messages.append(optimistic)

        Task {
            defer { isSending = false }
            do {
                let sent = try await ConversationsService.shared.reply(
                    id: conversation.id,
                    platform: conversation.platform,
                    body: text,
                    subject: subject,
                    phoneLineId: conversation.isSms ? phoneLineManager.selectedLine?.id : nil
                )
                messages.removeAll { $0.id == optimisticId }
                if let sent {
                    messages.append(sent)
                } else {
                    // Email: server just returned ok, keep a local placeholder
                    let confirmed = ConversationMessage(
                        id: Int.random(in: 100_000...999_999),
                        type: "email", body: text, direction: "outbound",
                        read: true, sentAt: Date(),
                        fromNumber: nil, toNumber: nil, status: "sent",
                        subject: subject, fromEmail: nil, toEmail: nil
                    )
                    messages.append(confirmed)
                }
                if conversation.isEmail { showSubjectField = false }
            } catch {
                messages.removeAll { $0.id == optimisticId }
                replyText = text
                sendError = "Failed to send. Tap to retry."
            }
        }
    }

    // MARK: - Scroll

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    @ViewBuilder
    private func fromRow(line: PhoneLine, canPick: Bool) -> some View {
        if canPick {
            Button { showPhoneLinePicker = true } label: {
                fromLabel(name: line.displayName, showChevron: true)
            }
            .confirmationDialog("Send from", isPresented: $showPhoneLinePicker, titleVisibility: .visible) {
                ForEach(phoneLineManager.phoneLines) { l in
                    Button(l.displayName) { phoneLineManager.select(l) }
                }
            }
        } else {
            fromLabel(name: line.displayName, showChevron: false)
        }
    }

    private func fromLabel(name: String, showChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text("From:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(name)
                .font(.caption)
                .foregroundColor(showChevron ? Self.outboundColor : .secondary)
            if showChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(Self.outboundColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}

// MARK: - Thread Bubble

struct ThreadBubble: View {
    let message: ConversationMessage
    let platform: String

    private var isOutbound: Bool { message.direction == "outbound" }
    private static let outboundColor = Color(red: 0.58, green: 0.18, blue: 0.98)

    var body: some View {
        HStack {
            if isOutbound { Spacer(minLength: 60) }

            VStack(alignment: isOutbound ? .trailing : .leading, spacing: 3) {
                // Email subject label
                if let subject = message.subject, !subject.isEmpty {
                    Text(subject)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }

                let bodyText = message.body?.strippingHTML ?? ""
                if !bodyText.isEmpty {
                    Text(bodyText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isOutbound ? Self.outboundColor : Color(.systemGray5))
                        .foregroundColor(isOutbound ? .white : .primary)
                        .clipShape(BubbleShape(isOutbound: isOutbound))
                }

                HStack(spacing: 4) {
                    if let sentAt = message.sentAt {
                        Text(sentAt.relativeFormatted)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if isOutbound, platform == "sms" {
                        smsStatusIcon(message.status)
                    }
                }
            }

            if !isOutbound { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private func smsStatusIcon(_ status: String?) -> some View {
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

// MARK: - HTML Stripping

extension String {
    var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
