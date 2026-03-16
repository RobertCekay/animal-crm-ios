//
//  AccountManager.swift
//  Animal CRM
//
//  Manages multi-account state. Every API request is scoped to currentAccount
//  via the X-Account-Id header set in APIService.buildRequest.
//

import Foundation
import Combine

extension Notification.Name {
    static let accountDidSwitch = Notification.Name("accountDidSwitch")
    static let conversationRead  = Notification.Name("conversationRead")
}

class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published var accounts: [Account] = []
    @Published var currentAccount: Account?
    @Published private(set) var switchToken = UUID()

    private let defaults = UserDefaults.standard
    private init() {}

    /// Called right after login with the freshly fetched account list.
    func load(accounts: [Account]) {
        self.accounts = accounts
        let savedId = defaults.integer(forKey: "selected_account_id")
        currentAccount = accounts.first { $0.id == savedId } ?? accounts.first
    }

    func switchTo(_ account: Account) {
        guard account.id != currentAccount?.id else { return }
        currentAccount = account
        defaults.set(account.id, forKey: "selected_account_id")
        switchToken = UUID()
        NotificationCenter.default.post(name: .accountDidSwitch, object: nil)
    }

    func signOut() {
        accounts = []
        currentAccount = nil
        defaults.removeObject(forKey: "selected_account_id")
    }
}
