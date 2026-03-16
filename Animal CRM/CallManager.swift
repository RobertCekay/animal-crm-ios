//
//  CallManager.swift
//  Animal CRM
//
//  Singleton that owns the Twilio Voice SDK call lifecycle.
//

import Foundation
import AVFoundation
import TwilioVoice
import Combine

@MainActor
final class CallManager: NSObject, ObservableObject {
    static let shared = CallManager()

    nonisolated let objectWillChange = ObservableObjectPublisher()

    @Published var callState: CallState = .idle
    @Published var callDuration: Int = 0
    @Published var isMuted = false
    @Published var isSpeaker = false
    @Published var callerDisplayName = ""
    @Published var errorMessage: String?

    private var activeCall: Call?
    private var durationTimer: Timer?
    private var cachedToken: CallToken?
    private var tokenFetchedAt: Date?

    enum CallState: Equatable {
        case idle
        case connecting
        case connected(String)
        case ended
    }

    private override init() { super.init() }

    // MARK: - Public API

    func dial(to phoneNumber: String, displayName: String) {
        guard callState == .idle else { return }
        callerDisplayName = displayName
        callState = .connecting
        Task {
            do {
                let token = try await freshToken()
                let opts = ConnectOptions(accessToken: token.token) { b in
                    b.params = ["To": phoneNumber]
                }
                self.activeCall = TwilioVoiceSDK.connect(options: opts, delegate: self)
            } catch {
                self.callState = .idle
                self.errorMessage = Self.userMessage(error)
            }
        }
    }

    func hangUp() { activeCall?.disconnect() }

    func toggleMute() {
        isMuted.toggle()
        activeCall?.isMuted = isMuted
    }

    func toggleSpeaker() {
        isSpeaker.toggle()
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(isSpeaker ? .speaker : .none)
    }

    /// Called by CallView after the 1.5 s "Call Ended" delay.
    func dismissAfterEnd() {
        callState = .idle
        callDuration = 0
        isMuted = false
        isSpeaker = false
        activeCall = nil
    }

    // MARK: - App Launch Setup

    nonisolated static func setup() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try? session.setActive(true)
        TwilioVoiceSDK.audioDevice = DefaultAudioDevice()
        session.requestRecordPermission { _ in }
    }

    // MARK: - Token (55 min cache)

    private func freshToken() async throws -> CallToken {
        if let t = cachedToken, let at = tokenFetchedAt,
           Date().timeIntervalSince(at) < 3300 { return t }
        let phoneLineId = PhoneLineManager.shared.selectedLine?.id
        let t = try await APIService.shared.fetchCallToken(phoneLineId: phoneLineId)
        cachedToken = t
        tokenFetchedAt = Date()
        return t
    }

    // MARK: - Duration Timer

    private func startTimer() {
        callDuration = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.callDuration += 1 }
        }
    }

    private func stopTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Helpers

    nonisolated private static func userMessage(_ error: Error) -> String {
        let d = error.localizedDescription
        if d.contains("no_phone_line") { return "No phone line is configured for this account." }
        if d.contains("token")        { return "Could not connect to calling service. Try again." }
        return d
    }
}

// MARK: - CallDelegate

extension CallManager: CallDelegate {

    nonisolated func callDidStartRinging(call: Call) { }

    nonisolated func callDidConnect(call: Call) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            callState = .connected(callerDisplayName)
            startTimer()
        }
    }

    nonisolated func callDidDisconnect(call: Call, error: Error?) {
        Task { @MainActor [weak self] in
            self?.callState = .ended
            self?.stopTimer()
        }
    }

    nonisolated func callDidFailToConnect(call: Call, error: Error) {
        let msg = Self.userMessage(error)
        Task { @MainActor [weak self] in
            self?.errorMessage = msg
            self?.callState = .idle
            self?.stopTimer()
        }
    }
}
