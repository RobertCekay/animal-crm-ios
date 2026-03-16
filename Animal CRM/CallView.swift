//
//  CallView.swift
//  Animal CRM
//
//  Full-screen active call UI. Presented via .fullScreenCover in AnimalCRMApp
//  whenever CallManager.shared.callState != .idle.
//

import SwiftUI

struct CallView: View {
    @ObservedObject private var cm = CallManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Avatar + contact info
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 96, height: 96)
                        Text(initials)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text(contactName)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(statusLabel)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                        .monospacedDigit()
                        .animation(.default, value: statusLabel)
                }

                Spacer()

                // Mute + Speaker toggles
                HStack(spacing: 56) {
                    CallToggleButton(
                        icon: cm.isMuted ? "mic.slash.fill" : "mic.fill",
                        label: cm.isMuted ? "Unmute" : "Mute",
                        active: cm.isMuted
                    ) { cm.toggleMute() }

                    CallToggleButton(
                        icon: "speaker.wave.3.fill",
                        label: "Speaker",
                        active: cm.isSpeaker
                    ) { cm.toggleSpeaker() }
                }
                .padding(.bottom, 52)

                // End call
                Button(action: { cm.hangUp() }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 72, height: 72)
                        Image(systemName: "phone.down.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 56)
            }
            .padding(.horizontal, 40)
        }
        .onChange(of: cm.callState) { state in
            if case .ended = state {
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run { cm.dismissAfterEnd() }
                }
            }
        }
    }

    private var contactName: String {
        if case .connected(let n) = cm.callState { return n }
        return cm.callerDisplayName.isEmpty ? "Calling…" : cm.callerDisplayName
    }

    private var initials: String {
        String(contactName.prefix(1)).uppercased()
    }

    private var statusLabel: String {
        switch cm.callState {
        case .idle:                return ""
        case .connecting:          return "Connecting…"
        case .connected:           return formattedDuration
        case .ended:               return "Call Ended"
        }
    }

    private var formattedDuration: String {
        let m = cm.callDuration / 60
        let s = cm.callDuration % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Toggle Button

private struct CallToggleButton: View {
    let icon: String
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(active ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(active ? .black : .white)
                }
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

#Preview {
    CallView()
}
