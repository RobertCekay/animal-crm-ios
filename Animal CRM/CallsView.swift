//
//  CallsView.swift
//  Animal CRM
//
//  Call history and outbound calling via Twilio (through Rails API)
//
//  NOTE: Outbound calling requires the Twilio Voice iOS SDK.
//  Add via Xcode → File → Add Package Dependencies:
//  https://github.com/twilio/twilio-voice-ios
//  Then uncomment the TwilioVoice import and calling code below.
//

import SwiftUI

struct CallsView: View {
    @EnvironmentObject var api: APIService
    @State private var calls: [CallRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading && calls.isEmpty {
                    ProgressView("Loading calls...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if calls.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No calls yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(calls) { call in
                        CallRow(call: call)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                    .listStyle(.plain)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Calls")
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
        .onAppear { Task { await load() } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            calls = try await api.fetchCallHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CallRow: View {
    let call: CallRecord

    var body: some View {
        HStack(spacing: 12) {
            // Direction icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(call.direction == "inbound" ? (call.fromNumber ?? "Unknown") : (call.toNumber ?? "Unknown"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(statusLabel)
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let date = call.startedAt ?? Optional(call.createdAt) {
                    Text(date.relativeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let dur = call.durationDisplay {
                    Text(dur)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var displayName: String {
        if let name = call.leadName, !name.isEmpty { return name }
        return call.direction == "inbound"
            ? (call.fromNumber ?? "Unknown Caller")
            : (call.toNumber ?? "Unknown Number")
    }

    private var iconName: String {
        switch call.status {
        case "missed", "no-answer", "busy": return "phone.down.fill"
        case "failed": return "exclamationmark.phone.fill"
        default: return call.direction == "inbound" ? "phone.arrow.down.left.fill" : "phone.arrow.up.right.fill"
        }
    }

    private var iconColor: Color {
        switch call.status {
        case "missed", "no-answer", "busy", "failed": return .red
        default: return call.direction == "inbound" ? .green : .blue
        }
    }

    private var statusLabel: String {
        switch call.status {
        case "completed": return "Completed"
        case "failed": return "Failed"
        case "busy": return "Busy"
        case "no-answer": return "No Answer"
        case "canceled": return "Canceled"
        case "in-progress": return "In Progress"
        default: return call.status.capitalized
        }
    }

    private var statusColor: Color {
        switch call.status {
        case "completed": return .secondary
        case "failed", "busy", "no-answer": return .red
        case "in-progress": return .green
        default: return .secondary
        }
    }
}

// MARK: - Outbound Call Button
// Use this view on a Lead or Job detail screen to initiate a call.
// It fetches a Twilio token then dials via the system phone app as a fallback
// until the Twilio Voice iOS SDK is integrated.

struct OutboundCallButton: View {
    let toNumber: String
    let leadName: String

    @EnvironmentObject var api: APIService
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Button {
            initiateCall()
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "phone.fill")
                }
                Text("Call")
            }
        }
        .disabled(isLoading)
        .alert("Call Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func initiateCall() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                // Fetch a fresh Twilio token from Rails
                let _ = try await api.fetchCallToken()

                // TODO: Once Twilio Voice iOS SDK is added via SPM, replace the
                // tel: fallback below with:
                //   TwilioVoice.connect(accessToken: tokenObj.token,
                //                       params: ["To": toNumber],
                //                       delegate: callDelegate)
                //
                // For now, open the system dialer so calls still work:
                let cleaned = toNumber.filter { $0.isNumber || $0 == "+" }
                if let url = URL(string: "tel://\(cleaned)") {
                    await UIApplication.shared.open(url)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    CallsView()
        .environmentObject(APIService.shared)
}
