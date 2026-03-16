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
    @StateObject private var callManager = CallManager.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        APIConfig.printConfig()
        CallManager.setup()   // configure AVAudioSession + request mic permission
    }

    var body: some Scene {
        WindowGroup {
            if apiService.isAuthenticated {
                ContentView()
                    .id(accountManager.switchToken)
                    .environmentObject(apiService)
                    .environmentObject(authManager)
                    .environmentObject(pushManager)
                    .task {
                        await ClockInManager.shared.checkStatus()
                        // Restore accounts when already logged in (bypasses login flow)
                        if AccountManager.shared.currentAccount == nil,
                           let accounts = try? await apiService.fetchAccounts() {
                            AccountManager.shared.load(accounts: accounts)
                        }
                        await PhoneLineManager.shared.load()
                    }
                    .fullScreenCover(isPresented: Binding(
                        get: { callManager.callState != .idle },
                        set: { _ in }
                    )) {
                        CallView()
                    }
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
