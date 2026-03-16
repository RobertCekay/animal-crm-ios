//
//  ContentView.swift
//  Animal CRM
//
//  Main tab navigation view
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard
    @ObservedObject private var callManager = CallManager.shared
    @ObservedObject private var pushManager = PushNotificationManager.shared
    @StateObject private var inboxVM = InboxViewModel()

    enum Tab {
        case dashboard, jobs, messages, estimates, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
                .tag(Tab.dashboard)

            MessagesView()
                .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                .tag(Tab.jobs)

            NavigationView {
                EstimateListView()
                    .environmentObject(APIService.shared)
            }
            .tabItem { Label("Estimates", systemImage: "doc.text.fill") }
            .tag(Tab.estimates)

            MessagesCenterView(inboxVM: inboxVM)
                .tabItem { Label("Messages", systemImage: "message.fill") }
                .badge(inboxVM.unreadCount)
                .tag(Tab.messages)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .accentColor(.blue)
        .onChange(of: pushManager.pendingThread) { thread in
            if thread != nil { selectedTab = .messages }
        }
        .alert("Call Error", isPresented: Binding(
            get: { callManager.errorMessage != nil },
            set: { if !$0 { callManager.errorMessage = nil } }
        )) {
            Button("OK") { callManager.errorMessage = nil }
        } message: {
            Text(callManager.errorMessage ?? "")
        }
    }
}

// MARK: - Messages Center (Inbox + Call History)

struct MessagesCenterView: View {
    @ObservedObject var inboxVM: InboxViewModel
    @EnvironmentObject var api: APIService
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var segment: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    Text("Inbox").tag(0)
                    Text("Calls").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))

                if segment == 0 {
                    InboxContent(vm: inboxVM)
                        .environmentObject(pushManager)
                } else {
                    CallsContent()
                        .environmentObject(api)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Call history without its own NavigationView wrapper.
private struct CallsContent: View {
    @EnvironmentObject var api: APIService
    @State private var calls: [CallRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && calls.isEmpty {
                ProgressView("Loading calls...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if calls.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No calls yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(calls) { call in
                    Button {
                        let phone = (call.direction == "outbound" ? call.toNumber : call.fromNumber)
                            ?? call.toNumber ?? call.fromNumber
                        if let phone {
                            CallManager.shared.dial(to: phone, displayName: call.leadName ?? phone)
                        }
                    } label: {
                        CallRow(call: call).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .onAppear { Task { await load() } }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { calls = try await api.fetchCallHistory() }
        catch { errorMessage = error.localizedDescription }
    }
}

#Preview {
    ContentView()
        .environmentObject(APIService.shared)
        .environmentObject(PushNotificationManager.shared)
}
