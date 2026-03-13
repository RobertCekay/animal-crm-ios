//
//  SMSThreadView.swift
//  Animal CRM
//
//  SMS conversation thread with chat bubbles and reply
//

import SwiftUI

struct SMSThreadView: View {
    let conversation: SmsConversation

    @EnvironmentObject var api: APIService
    @State private var messages: [SmsMessage] = []
    @State private var replyText = ""
    @State private var isSending = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
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

                Button {
                    send()
                } label: {
                    Image(systemName: isSending ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(replyText.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
                }
                .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle(conversation.leadName.isEmpty ? conversation.contactNumber : conversation.leadName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading { ProgressView() }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .onAppear { Task { await load() } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let thread = try await api.fetchSmsThread(conversationId: conversation.id)
            messages = thread.messages
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() {
        let text = replyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        replyText = ""
        isSending = true
        Task {
            defer { isSending = false }
            do {
                let sent = try await api.replySms(conversationId: conversation.id, body: text)
                messages.append(sent)
            } catch {
                errorMessage = error.localizedDescription
                replyText = text
            }
        }
    }
}

struct ChatBubble: View {
    let message: SmsMessage

    var isOutbound: Bool { message.direction == "outbound" }

    var body: some View {
        HStack {
            if isOutbound { Spacer(minLength: 60) }

            VStack(alignment: isOutbound ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isOutbound ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isOutbound ? .white : .primary)
                    .clipShape(BubbleShape(isOutbound: isOutbound))

                HStack(spacing: 4) {
                    Text(message.sentAt.relativeFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if isOutbound {
                        statusIcon(message.status)
                    }
                }
            }

            if !isOutbound { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: String) -> some View {
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
