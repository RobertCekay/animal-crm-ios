//
//  ContentView.swift
//  Animal CRM
//
//  Main tab navigation view
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab {
        case dashboard
        case jobs
        case estimates
        case settings
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

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(APIService.shared)
        .environmentObject(PushNotificationManager.shared)
}
