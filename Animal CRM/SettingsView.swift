//
//  SettingsView.swift
//  Animal CRM
//
//  Native settings view with Sign in with Apple and preferences
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var notificationManager: PushNotificationManager
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            Form {
                // Account Section
                Section {
                    if let user = apiService.currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.fullName)
                                .font(.body)
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let role = user.role {
                                Text(role.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.backward.circle.fill")
                            Text("Sign Out")
                        }
                    }
                } header: {
                    Text("Account")
                }
                
                // Notifications Section
                Section {
                    HStack {
                        Text("Push Notifications")
                        Spacer()
                        switch notificationManager.authorizationStatus {
                        case .authorized:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Enabled")
                                .foregroundColor(.secondary)
                        case .denied:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Disabled")
                                .foregroundColor(.secondary)
                        case .notDetermined:
                            Button("Enable") {
                                Task {
                                    await notificationManager.requestAuthorization()
                                }
                            }
                        default:
                            Text("Unknown")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if notificationManager.authorizationStatus == .denied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    
                    if let deviceToken = notificationManager.deviceToken {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Device Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(deviceToken)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive important updates and messages from Animal CRM")
                }
                
                // App Information Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("App Information")
                }
                
                // Support Section
                Section {
                    Link(destination: URL(string: "https://animalcrm.com/support")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Help & Support")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://animalcrm.com/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://animalcrm.com/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Support")
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    apiService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIService.shared)
        .environmentObject(PushNotificationManager.shared)
}
