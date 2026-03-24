//
//  NewConversationView.swift
//  Animal CRM
//
//  Compose screen for starting a new conversation with a lead.
//  Flow: search lead → pick channel → write message → send → open thread.
//

import SwiftUI

struct NewConversationView: View {
    /// Called on successful send. Caller should dismiss the sheet and navigate to this lead.
    let onSent: (Lead) -> Void

    @State private var searchText = ""
    @State private var searchResults: [Lead] = []
    @State private var isSearching = false
    @State private var selectedLead: Lead?
    @State private var selectedChannel: MessageChannel = .sms
    @State private var bodyText = ""
    @State private var emailSubject = ""
    @State private var isSending = false
    @State private var sendError: String?
    @State private var showPhoneLinePicker = false
    @State private var searchTask: Task<Void, Never>?

    @ObservedObject private var phoneLineManager = PhoneLineManager.shared
    @FocusState private var bodyFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private static let purple = Color(red: 0.58, green: 0.18, blue: 0.98)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                toRow
                Divider()

                if let lead = selectedLead {
                    leadComposer(lead: lead)
                } else {
                    searchContent
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - To row

    private var toRow: some View {
        HStack(spacing: 8) {
            Text("To:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 16)

            if let lead = selectedLead {
                HStack(spacing: 6) {
                    Text(lead.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Button {
                        clearLead()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                Spacer()
            } else {
                TextField("Name, phone, or email", text: $searchText)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchText) { _ in debounceSearch() }
                    .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 12)
        .padding(.trailing, selectedLead != nil ? 16 : 0)
    }

    // MARK: - Search content

    private var searchContent: some View {
        Group {
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchText.isEmpty && searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No leads found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Search for a lead to start a conversation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchResults) { lead in
                    Button { selectLead(lead) } label: {
                        leadRow(lead)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }

    private func leadRow(_ lead: Lead) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(avatarColor(for: lead).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(lead.name.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(avatarColor(for: lead))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(lead.name).font(.body)
                    if lead.phone == nil && lead.email == nil {
                        Text("No contact info")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    if let phone = lead.phone {
                        Label(phone, systemImage: "phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let email = lead.email {
                        Label(email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(availableChannels(for: lead).isEmpty ? 0.4 : 1)
    }

    // MARK: - Composer (after lead selected)

    @ViewBuilder
    private func leadComposer(lead: Lead) -> some View {
        let channels = availableChannels(for: lead)

        if channels.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No contact info on file for \(lead.name).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Channel picker — only when both are available
            if channels.count > 1 {
                Picker("", selection: $selectedChannel) {
                    ForEach(channels, id: \.self) { ch in
                        Label(ch.label, systemImage: ch.icon).tag(ch)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                Divider()
            }

            // From: phone line (SMS only)
            if selectedChannel == .sms, let line = phoneLineManager.selectedLine {
                fromRow(line: line, canPick: phoneLineManager.phoneLines.count > 1)
                Divider().padding(.top, 6)
            }

            // Subject (email only)
            if selectedChannel == .email {
                HStack {
                    Text("Subject:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Subject", text: $emailSubject)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider()
            }

            Spacer()

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

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $bodyText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($bodyFocused)

                Button { send(lead: lead) } label: {
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

    // MARK: - From row

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Computed

    private var canSend: Bool {
        !bodyText.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    private func availableChannels(for lead: Lead) -> [MessageChannel] {
        var channels: [MessageChannel] = []
        if lead.email != nil { channels.append(.email) }
        if lead.phone != nil && !phoneLineManager.phoneLines.isEmpty { channels.append(.sms) }
        return channels
    }

    // MARK: - Search

    private func debounceSearch() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        defer { isSearching = false }
        searchResults = (try? await APIService.shared.fetchLeads(query: query).leads) ?? []
    }

    // MARK: - Lead selection

    private func selectLead(_ lead: Lead) {
        guard !availableChannels(for: lead).isEmpty else { return }
        selectedLead = lead
        searchText = ""
        searchResults = []
        let channels = availableChannels(for: lead)
        if let first = channels.first { selectedChannel = first }
        emailSubject = "Message from \(AccountManager.shared.currentAccount?.name ?? "")"
        bodyFocused = true
    }

    private func clearLead() {
        selectedLead = nil
        bodyText = ""
        emailSubject = ""
        sendError = nil
    }

    // MARK: - Send

    private func send(lead: Lead) {
        let text = bodyText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let subject = selectedChannel == .email && !emailSubject.isEmpty ? emailSubject : nil
        isSending = true
        sendError = nil

        Task {
            defer { isSending = false }
            do {
                _ = try await APIService.shared.sendLeadMessage(
                    leadId: lead.id,
                    channel: selectedChannel.rawValue,
                    body: text,
                    subject: subject,
                    phoneLineId: selectedChannel == .sms ? phoneLineManager.selectedLine?.id : nil
                )
                onSent(lead)
            } catch {
                sendError = userMessage(error)
            }
        }
    }

    private func userMessage(_ error: Error) -> String {
        let d = error.localizedDescription
        if d.contains("no_email")      { return "This contact has no email address on file." }
        if d.contains("no_phone")      { return "This contact has no phone number on file." }
        if d.contains("no_phone_line") { return "No phone line configured. Set one up in Settings." }
        if d.contains("body_required") { return "Please enter a message." }
        return "Failed to send. Please try again."
    }

    private func avatarColor(for lead: Lead) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .indigo]
        return palette[abs(lead.name.hashValue) % palette.count]
    }
}
