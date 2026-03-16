//
//  InboxView.swift
//  Animal CRM
//
//  Unified conversations inbox — one row per lead, SMS + Email combined.
//  Tapping a row opens LeadConversationView (unified feed + channel picker).
//

import SwiftUI
import Combine

// MARK: - Lead Thread (grouped view model)

/// One row in the inbox — represents all conversations for a single lead.
struct LeadThread: Identifiable {
    let id: Int                 // lead_id
    let name: String
    let phone: String?
    let snippet: String?
    let unreadCount: Int
    let lastMessageAt: Date?

    /// Minimal Lead to pass to LeadConversationView.
    var lead: Lead {
        Lead(id: id, name: name, email: nil, phone: phone,
             address: nil, source: nil, status: nil, tags: nil,
             notes: nil, createdAt: Date())
    }

    var initials: String { String(name.prefix(1)).uppercased() }
}

// MARK: - View Model

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Conversations grouped by lead — one row per lead, sorted newest first.
    /// Conversations without a lead_id fall back to individual rows.
    var leadThreads: [LeadThread] {
        var dict: [Int: [Conversation]] = [:]
        var orphans: [Conversation] = []

        for c in conversations {
            if let lid = c.leadId {
                dict[lid, default: []].append(c)
            } else {
                orphans.append(c)
            }
        }

        let grouped = dict.map { (leadId, convos) -> LeadThread in
            let latest = convos.max(by: {
                ($0.lastMessageAt ?? .distantPast) < ($1.lastMessageAt ?? .distantPast)
            })!
            return LeadThread(
                id: leadId,
                name: latest.displayName,
                phone: convos.first(where: { $0.isSms })?.contactNumber,
                snippet: latest.snippet,
                unreadCount: convos.reduce(0) { $0 + $1.unreadCount },
                lastMessageAt: latest.lastMessageAt
            )
        }

        // Orphan conversations (no lead_id) get their own row with a synthetic negative id
        let ungrouped = orphans.map { c in
            LeadThread(
                id: -c.id,
                name: c.displayName,
                phone: c.contactNumber,
                snippet: c.snippet,
                unreadCount: c.unreadCount,
                lastMessageAt: c.lastMessageAt
            )
        }

        return (grouped + ungrouped)
            .sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
    }

    var unreadCount: Int { leadThreads.filter { $0.unreadCount > 0 }.count }

    private var pollingTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] q in
                self?.searchTask?.cancel()
                self?.searchTask = Task { await self?.load(query: q) }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .conversationRead)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                // Optimistically zero unread counts for the opened lead immediately
                if let leadId = notification.object as? Int {
                    for i in self.conversations.indices where self.conversations[i].leadId == leadId {
                        self.conversations[i].unreadCount = 0
                    }
                }
                Task { await self.load() }
            }
            .store(in: &cancellables)
    }

    func load(query: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let q = (query ?? searchText).isEmpty ? nil : (query ?? searchText)
            conversations = try await ConversationsService.shared.fetchInbox(query: q)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !Task.isCancelled { await load() }
            }
        }
    }

    func stopPolling() { pollingTask?.cancel() }

    /// Find the lead thread that contains a given conversation (for push nav).
    func leadThread(forConversationId id: Int, platform: String) -> LeadThread? {
        guard let convo = conversations.first(where: { $0.id == id && $0.platform == platform }),
              let leadId = convo.leadId else { return nil }
        return leadThreads.first(where: { $0.id == leadId })
    }
}

// MARK: - Inbox Content (embedded inside MessagesCenterView — no NavigationView)

struct InboxContent: View {
    @ObservedObject var vm: InboxViewModel
    @EnvironmentObject var pushManager: PushNotificationManager

    @State private var navigateToLead: Lead?
    @State private var isNavigating = false
    @State private var showingCompose = false

    var body: some View {
        Group {
            if vm.isLoading && vm.leadThreads.isEmpty {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.leadThreads.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCompose = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingCompose) {
            NewConversationView { lead in
                showingCompose = false
                navigateToLead = lead
                isNavigating = true
                Task { await vm.load() }
            }
        }
        .onAppear {
            Task { await vm.load() }
            vm.startPolling()
            handlePending()
        }
        .onDisappear { vm.stopPolling() }
        .onChange(of: pushManager.pendingThread) { _ in handlePending() }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var list: some View {
        List {
            // Hidden push-notification navigation link
            NavigationLink(
                destination: navigateToLead.map { LeadConversationView(lead: $0) },
                isActive: $isNavigating
            ) { EmptyView() }.hidden()

            ForEach(vm.leadThreads) { thread in
                NavigationLink(destination: LeadConversationView(lead: thread.lead)) {
                    InboxRow(thread: thread)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .searchable(text: $vm.searchText, prompt: "Search conversations")
        .refreshable { await vm.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(vm.searchText.isEmpty ? "No conversations yet" : "No results")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(text: $vm.searchText, prompt: "Search conversations")
        .refreshable { await vm.load() }
    }

    private func handlePending() {
        guard let pending = pushManager.pendingThread else { return }
        pushManager.pendingThread = nil
        if let thread = vm.leadThread(forConversationId: pending.id, platform: pending.platform) {
            navigateToLead = thread.lead
        } else {
            // Conversations not yet loaded — create a placeholder lead from the pending info
            navigateToLead = Lead(
                id: pending.id, name: "Loading…", email: nil, phone: nil,
                address: nil, source: nil, status: nil, tags: nil,
                notes: nil, createdAt: Date()
            )
        }
        isNavigating = true
    }
}

// MARK: - Inbox Row

struct InboxRow: View {
    let thread: LeadThread

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Text(thread.initials)
                    .font(.headline)
                    .foregroundColor(avatarColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(thread.name)
                        .font(thread.unreadCount > 0 ? .headline : .body)
                        .lineLimit(1)
                    Spacer()
                    if let date = thread.lastMessageAt {
                        Text(date.relativeFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text(thread.snippet ?? "No messages")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fontWeight(thread.unreadCount > 0 ? .semibold : .regular)
                        .lineLimit(1)
                    Spacer()
                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount)")
                            .font(.caption2).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var avatarColor: Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .indigo]
        return palette[abs(thread.name.hashValue) % palette.count]
    }
}

// MARK: - Platform Badge (still used in ThreadView)

struct PlatformBadge: View {
    let platform: String

    var body: some View {
        Text(platform.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(platform == "email" ? Color.blue : Color(.darkGray))
            .clipShape(Capsule())
    }
}
