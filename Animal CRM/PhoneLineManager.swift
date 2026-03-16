//
//  PhoneLineManager.swift
//  Animal CRM
//
//  Fetches and caches phone lines for the current account.
//  Re-fetched on account switch. Selected line persisted in UserDefaults.
//

import Foundation
import Combine

@MainActor
final class PhoneLineManager: ObservableObject {
    static let shared = PhoneLineManager()

    @Published var phoneLines: [PhoneLine] = []
    @Published var selectedLine: PhoneLine?

    private let defaults = UserDefaults.standard
    private let selectedLineKey = "selected_phone_line_id"

    private init() {}

    func load() async {
        guard let lines = try? await APIService.shared.fetchPhoneLines() else { return }
        phoneLines = lines
        let savedId = defaults.integer(forKey: selectedLineKey)
        selectedLine = lines.first { $0.id == savedId } ?? lines.first
    }

    func select(_ line: PhoneLine) {
        selectedLine = line
        defaults.set(line.id, forKey: selectedLineKey)
    }
}
