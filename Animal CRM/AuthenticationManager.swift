//
//  AuthenticationManager.swift
//  Animal CRM
//
//  Manages Sign in with Apple authentication
//

import Foundation
import Combine
import AuthenticationServices
import Security
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var userIdentifier: String?
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var authorizationCode: String?
    @Published var identityToken: String?
    
    private let keychainService = "com.animalcrm.app"
    private let userIdentifierKey = "appleUserIdentifier"
    
    private init() {
        // Check for existing authentication on initialization
        checkAuthenticationState()
    }
    
    // MARK: - Public Methods
    
    func handleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                await processAppleIDCredential(appleIDCredential)
            }
        case .failure(let error):
            print("❌ Sign in with Apple failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func signOut() {
        // Clear user data
        isAuthenticated = false
        userIdentifier = nil
        userName = nil
        userEmail = nil
        authorizationCode = nil
        identityToken = nil
        
        // Remove from keychain
        deleteFromKeychain(key: userIdentifierKey)
        
        print("✅ Signed out successfully")
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func processAppleIDCredential(_ credential: ASAuthorizationAppleIDCredential) async {
        // Extract user information
        let userID = credential.user
        userIdentifier = userID
        
        // Get full name if available
        if let fullName = credential.fullName {
            let firstName = fullName.givenName ?? ""
            let lastName = fullName.familyName ?? ""
            userName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        }
        
        // Get email if available
        if let email = credential.email {
            userEmail = email
        }
        
        // Get authorization code
        if let authCodeData = credential.authorizationCode,
           let authCode = String(data: authCodeData, encoding: .utf8) {
            authorizationCode = authCode
        }
        
        // Get identity token
        if let identityTokenData = credential.identityToken,
           let token = String(data: identityTokenData, encoding: .utf8) {
            identityToken = token
        }
        
        // Save to keychain
        saveToKeychain(value: userID, key: userIdentifierKey)
        
        // Update authentication state
        isAuthenticated = true
        
        // Send token to Rails backend
        await sendAuthenticationToBackend()
        
        print("✅ Signed in successfully with user ID: \(userID)")
    }
    
    private func checkAuthenticationState() {
        if let userID = getFromKeychain(key: userIdentifierKey) {
            userIdentifier = userID
            
            // Verify the credential is still valid
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userID) { [weak self] state, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch state {
                    case .authorized:
                        self.isAuthenticated = true
                        print("✅ User is authenticated")
                    case .revoked, .notFound:
                        Task { @MainActor in
                            self.signOut()
                        }
                        print("⚠️ User authorization revoked or not found")
                    default:
                        self.isAuthenticated = false
                    }
                }
            }
        }
    }
    
    private func sendAuthenticationToBackend() async {
        guard let token = identityToken else {
            print("⚠️ No identity token available")
            return
        }
        
        // Prepare authentication data to send to Rails backend
        let authData: [String: Any] = [
            "identity_token": token,
            "authorization_code": authorizationCode ?? "",
            "user_identifier": userIdentifier ?? "",
            "email": userEmail ?? "",
            "name": userName ?? ""
        ]
        
        // Send to Rails backend
        guard let url = URL(string: APIConfig.appleAuthURL) else {
            print("❌ Invalid backend URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: authData)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Authentication sent to backend successfully")
                    
                    // Parse response if needed
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("Backend response: \(json)")
                    }
                } else {
                    print("❌ Backend returned status code: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Failed to send authentication to backend: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Keychain Helper Methods
    
    private func saveToKeychain(value: String, key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Saved to keychain: \(key)")
        } else {
            print("❌ Failed to save to keychain: \(status)")
        }
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

