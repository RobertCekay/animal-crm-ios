//
//  LeadConversationView.swift
//  Animal CRM
//
//  Unified email + SMS + call feed for a lead. Attach as a NavigationLink
//  destination from any lead detail screen.
//
//  • Email outbound → right-aligned purple bubble with subject label
//  • SMS outbound   → right-aligned purple bubble with status tick
//  • Inbound        → left-aligned gray bubble
//  • Call           → centered gray pill, tappable to call back
//  • Polls every 15 s while open (append-only by sent_at)
//

import SwiftUI

// MARK: - Main View

struct LeadConversationView: View {
    let lead: Lead

    @State private var response: LeadMessagesResponse?
    @State private var messages: [LeadMessage] = []
    @State private var isLoading = false
    @State private var sendError: String?
    @State private var isSending = false

    // Composer state
    @State private var selectedChannel: MessageChannel = .email
    @State private var bodyText = ""
    @State private var emailSubject = ""
    @State private var showSubjectField = false
    @State private var pollingTask: Task<Void, Never>?
    @State private var showPhoneLinePicker = false
    @ObservedObject private var phoneLineManager = PhoneLineManager.shared
    @FocusState private var bodyFocused: Bool

    private let optimisticIdPrefix = "optimistic-"
    private static let purple = Color(red: 0.58, green: 0.18, blue: 0.98)

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                ProgressView("Loading conversation…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty && (response?.canEmail == false && response?.canSms == false) {
                emptyNoChanelState
            } else {
                messageList
            }

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
            composer
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await load() }
            startPolling()
        }
        .onDisappear { pollingTask?.cancel() }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { msg in
                        LeadMessageBubble(message: msg, lead: lead)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _ in scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy) }
        }
    }

    private var emptyNoChanelState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No contact info on file.")
                .font(.headline)
            Text("Add an email or phone number to start a conversation.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            // From: phone line row (SMS only, at least 1 line loaded)
            if selectedChannel == .sms, let line = phoneLineManager.selectedLine {
                fromRow(line: line, canPick: phoneLineManager.phoneLines.count > 1)
                Divider().padding(.top, 6)
            }

            if showSubjectField && selectedChannel == .email {
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

            HStack(alignment: .bottom, spacing: 8) {
                // Channel picker (only when both are available)
                if availableChannels.count > 1 {
                    Menu {
                        ForEach(availableChannels, id: \.self) { ch in
                            Button {
                                selectedChannel = ch
                                showSubjectField = false
                            } label: {
                                Label(ch.label, systemImage: ch.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: selectedChannel.icon)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                        }
                        .font(.subheadline)
                        .foregroundColor(Self.purple)
                        .padding(8)
                        .background(Self.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    TextField("Message", text: $bodyText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .focused($bodyFocused)
                        .onTapGesture {
                            if selectedChannel == .email && !showSubjectField {
                                showSubjectField = true
                                if emailSubject.isEmpty {
                                    emailSubject = "Message from \(AccountManager.shared.currentAccount?.name ?? "")"
                                }
                            }
                        }
                }

                Button { send() } label: {
                    Image(systemName: isSending ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? Self.purple : .secondary)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed

    private var availableChannels: [MessageChannel] {
        var ch: [MessageChannel] = []
        if response?.canEmail == true { ch.append(.email) }
        if response?.canSms   == true { ch.append(.sms) }
        return ch
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
                .foregroundColor(showChevron ? Self.purple : .secondary)
            if showChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(Self.purple)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var canSend: Bool {
        !bodyText.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
            && !availableChannels.isEmpty
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await APIService.shared.fetchLeadMessages(leadId: lead.id)
            response = r
            messages = r.messages
            if let first = availableChannels.first { selectedChannel = first }
            // Tell the inbox to refresh so unread badges clear immediately
            NotificationCenter.default.post(name: .conversationRead, object: lead.id)
        } catch { }
    }

    // MARK: - Polling (15 s, append-only)

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { break }
                await pollForNew()
            }
        }
    }

    private func pollForNew() async {
        guard let r = try? await APIService.shared.fetchLeadMessages(leadId: lead.id) else { return }
        let lastKnown = messages
            .compactMap { $0.sentAt ?? $0.startedAt }
            .max() ?? .distantPast
        let fresh = r.messages.filter { msg in
            let ts = msg.sentAt ?? msg.startedAt ?? .distantPast
            return ts > lastKnown && !messages.contains(where: { $0.id == msg.id })
        }
        if !fresh.isEmpty { messages.append(contentsOf: fresh) }
    }

    // MARK: - Send

    private func send() {
        let text = bodyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let subject = selectedChannel == .email && !emailSubject.isEmpty ? emailSubject : nil
        bodyText = ""
        sendError = nil
        isSending = true

        // Optimistic message
        let optimistic = LeadMessage(
            type: selectedChannel == .email ? .email : .sms,
            direction: "outbound",
            body: text,
            subject: subject,
            status: "sending",
            duration: nil, number: nil,
            sentAt: Date(), startedAt: nil, read: true
        )
        messages.append(optimistic)

        Task {
            defer { isSending = false }
            do {
                let result = try await APIService.shared.sendLeadMessage(
                    leadId: lead.id,
                    channel: selectedChannel.rawValue,
                    body: text,
                    subject: subject,
                    phoneLineId: selectedChannel == .sms ? phoneLineManager.selectedLine?.id : nil
                )
                messages.removeAll { $0.id == optimistic.id }
                messages.append(result.message)
                if selectedChannel == .email { showSubjectField = false }
            } catch {
                messages.removeAll { $0.id == optimistic.id }
                bodyText = text
                sendError = userMessage(error)
            }
        }
    }

    private func userMessage(_ error: Error) -> String {
        let d = error.localizedDescription
        if d.contains("no_email")      { return "Lead has no email address." }
        if d.contains("no_phone")      { return "Lead has no phone number." }
        if d.contains("no_phone_line") { return "No active phone line configured." }
        if d.contains("send_failed")   { return "Failed to send. Tap to retry." }
        return "Failed to send. Tap to retry."
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}

// MARK: - Message Bubble

private struct LeadMessageBubble: View {
    let message: LeadMessage
    let lead: Lead

    private static let purple = Color(red: 0.58, green: 0.18, blue: 0.98)

    var body: some View {
        switch message.type {
        case .call:
            callPill
        case .email, .sms:
            chatBubble
        }
    }

    // Chat bubble (email or sms)
    private var chatBubble: some View {
        HStack {
            if message.isOutbound { Spacer(minLength: 60) }

            VStack(alignment: message.isOutbound ? .trailing : .leading, spacing: 3) {
                if let subject = message.subject, !subject.isEmpty {
                    Text(subject)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                if let body = message.body?.strippingHTML, !body.isEmpty {
                    Text(body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(message.isOutbound ? Self.purple : Color(.systemGray5))
                        .foregroundColor(message.isOutbound ? .white : .primary)
                        .clipShape(BubbleShape(isOutbound: message.isOutbound))
                }
                HStack(spacing: 4) {
                    Image(systemName: message.type == .email ? "envelope" : "message")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    if let ts = message.sentAt {
                        Text(ts.relativeFormatted)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if message.isOutbound && message.type == .sms {
                        smsStatusIcon(message.status)
                    }
                }
            }

            if !message.isOutbound { Spacer(minLength: 60) }
        }
    }

    // Centered pill for calls
    private var callPill: some View {
        HStack(spacing: 6) {
            Image(systemName: callIcon)
                .foregroundColor(callColor)
            Text(callLabel)
                .font(.caption)
                .foregroundColor(.secondary)
            if let dur = message.duration {
                Text("· \(dur)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            let number = message.number ?? lead.phone ?? ""
            if !number.isEmpty {
                CallManager.shared.dial(to: number, displayName: lead.name)
            }
        }
    }

    private var callIcon: String {
        switch message.status {
        case "completed":
            return message.isOutbound ? "phone.arrow.up.right.fill" : "phone.arrow.down.left.fill"
        case "no-answer", "missed", "busy":
            return "phone.down.fill"
        default:
            return "phone.fill"
        }
    }

    private var callColor: Color {
        switch message.status {
        case "no-answer", "missed", "busy", "failed": return .red
        case "completed": return message.isOutbound ? .blue : .green
        default: return .secondary
        }
    }

    private var callLabel: String {
        let dir = message.isOutbound ? "Outbound call" : "Inbound call"
        switch message.status {
        case "completed":  return dir
        case "no-answer":  return "No answer"
        case "missed":     return "Missed call"
        case "busy":       return "Busy"
        case "failed":     return "Failed call"
        default:           return dir
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
