//
//  AnimalCRMApp.swift
//  Animal CRM
//
//  Main app entry point - Native iOS app with API integration
//

import SwiftUI

@main
struct AnimalCRMApp: App {
    @StateObject private var apiService = APIService.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var pushManager = PushNotificationManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Print current API configuration for debugging
        APIConfig.printConfig()
    }

    var body: some Scene {
        WindowGroup {
            if apiService.isAuthenticated {
                ContentView()
                    .environmentObject(apiService)
                    .environmentObject(authManager)
                    .environmentObject(pushManager)
                    .task { await ClockInManager.shared.checkStatus() }
            } else {
                LoginView()
                    .environmentObject(apiService)
                    .environmentObject(authManager)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, apiService.isAuthenticated {
                Task { await ClockInManager.shared.checkStatus() }
            }
        }
    }
}
