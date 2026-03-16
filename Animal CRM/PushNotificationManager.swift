//
//  PushNotificationManager.swift
//  Animal CRM
//
//  Manages push notifications and deep linking
//

import Foundation
import Combine
import UserNotifications
import UIKit

struct PendingThread: Equatable {
    let id: Int
    let platform: String
}

class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?
    @Published var deepLinkURL: String?
    @Published var pendingThread: PendingThread?
    
    private init() {
        // Check authorization status on initialization
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("✅ Push notification permission granted")
                await checkAuthorizationStatus()
            } else {
                print("⚠️ Push notification permission denied")
            }
        } catch {
            print("❌ Failed to request notification permission: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    @MainActor
    func updateDeviceToken(_ token: String) {
        deviceToken = token
        
        // Send token to Rails backend
        Task {
            await sendDeviceTokenToBackend(token)
        }
    }
    
    @MainActor
    func handleDeepLink(_ urlString: String) {
        deepLinkURL = urlString
        print("🔗 Deep link received: \(urlString)")
        
        // Post notification for WebView to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("HandleDeepLink"),
            object: nil,
            userInfo: ["url": urlString]
        )
    }
    
    // MARK: - Private Methods
    
    private func sendDeviceTokenToBackend(_ token: String) async {
        guard let url = URL(string: APIConfig.notificationRegisterURL) else {
            print("❌ Invalid backend URL")
            return
        }
        
        let payload: [String: Any] = [
            "device_token": token,
            "platform": "ios",
            "device_type": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Device token sent to backend successfully")
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("Backend response: \(json)")
                    }
                } else {
                    print("❌ Backend returned status code: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Failed to send device token to backend: \(error.localizedDescription)")
        }
    }
}
