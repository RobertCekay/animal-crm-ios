//
//  APIConfig.swift
//  Animal CRM
//
//  Centralized API configuration for development and production
//

import Foundation

struct APIConfig {
    
    // MARK: - Configuration Toggle
    
    /// Set to `true` to use localhost for development, `false` for production
    static let useLocalhost = true
    
    // MARK: - Development Configuration
    
    /// For iOS Simulator: use "localhost"
    /// For Physical Device: use your Mac's IP address (e.g., "192.168.1.100")
    /// To find your IP: Open Terminal and run: ipconfig getifaddr en0
    private static let developmentHost = "localhost"  // Change to "192.168.1.100" for physical device
    private static let developmentPort = "3000"
    
    // MARK: - Base URLs
    
    static var baseURL: String {
        useLocalhost ? "http://\(developmentHost):\(developmentPort)" : "https://www.animalcrm.com"
    }
    
    // MARK: - Endpoints
    
    /// Main web app URL
    static var homeURL: String {
        baseURL
    }
    
    /// Conversations page URL
    static var conversationsURL: String {
        "\(baseURL)/conversations"
    }
    
    /// Sign in with Apple authentication endpoint
    static var appleAuthURL: String {
        "\(baseURL)/api/auth/apple"
    }
    
    /// Push notification device registration endpoint
    static var notificationRegisterURL: String {
        "\(baseURL)/api/notifications/register"
    }
    
    /// Image upload endpoint
    static var uploadURL: String {
        "\(baseURL)/api/uploads"
    }
    
    // MARK: - Helper Methods
    
    /// Returns a URL object for the given endpoint string
    static func url(for endpoint: String) -> URL? {
        URL(string: endpoint)
    }
    
    /// Print current configuration (for debugging)
    static func printConfig() {
        print("🔧 API Configuration")
        print("   Environment: \(useLocalhost ? "Development (localhost)" : "Production")")
        print("   Base URL: \(baseURL)")
        print("   Auth: \(appleAuthURL)")
        print("   Notifications: \(notificationRegisterURL)")
        print("   Upload: \(uploadURL)")
    }
}
