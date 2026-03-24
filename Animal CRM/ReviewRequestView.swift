//
//  ReviewRequestView.swift
//  Animal CRM
//
//  Bottom sheet for sending a Google review request via email or SMS.
//

import SwiftUI

struct ReviewRequestSheet: View {
    let jobId: Int
    let customerName: String
    let customerEmail: String?
    let customerPhone: String?

    let onSuccess: (String) -> Void   // passes toast message back

    @Environment(\.dismiss) private var dismiss

    @State private var selectedChannel: ReviewChannel = .email
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var availableChannels: [ReviewChannel] {
        var channels: [ReviewChannel] = []
        if customerEmail != nil { channels.append(.email) }
        if customerPhone != nil { channels.append(.sms) }
        return channels
    }

    private var hasNoContact: Bool { availableChannels.isEmpty }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {

                        // Header
                        VStack(spacing: 6) {
                            Text("⭐ Request a Review")
                                .font(.title3.bold())
                            Text("Ask \(customerName) to leave a Google review")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // Customer info card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(customerName)
                                .font(.headline)
                            if let email = customerEmail {
                                Label(email, systemImage: "envelope")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let phone = customerPhone {
                                Label(phone, systemImage: "phone")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // Channel selector
                        if hasNoContact {
                            VStack(spacing: 8) {
                                Image(systemName: "person.crop.circle.badge.exclamationmark")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("This customer has no email or phone on file. Edit their contact info first.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Send via")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    ForEach(availableChannels, id: \.self) { channel in
                                        ChannelCard(
                                            channel: channel,
                                            isSelected: selectedChannel == channel
                                        ) {
                                            selectedChannel = channel
                                        }
                                    }
                                }
                            }
                        }

                        // Inline error
                        if let err = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }

                // Send button
                VStack(spacing: 12) {
                    Button {
                        Task { await send() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send Review Request")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(hasNoContact ? Color(.systemGray4) : Color(red: 0.95, green: 0.70, blue: 0.05))
                        .foregroundColor(hasNoContact ? Color(.systemGray) : .white)
                        .cornerRadius(12)
                    }
                    .disabled(hasNoContact || isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Review Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if let first = availableChannels.first {
                selectedChannel = first
            }
        }
    }

    private func send() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIService.shared.sendReviewRequest(jobId: jobId, channel: selectedChannel)
            if result.success {
                let via = selectedChannel == .email ? "email" : "text"
                dismiss()
                onSuccess("Review request sent via \(via)!")
            }
        } catch APIError.serverError(let message) {
            errorMessage = message
        } catch {
            errorMessage = "Network error. Please try again."
        }
    }
}

// MARK: - Channel Card

private struct ChannelCard: View {
    let channel: ReviewChannel
    let isSelected: Bool
    let onTap: () -> Void

    private var icon: String { channel == .email ? "envelope.fill" : "message.fill" }
    private var title: String { channel == .email ? "Email" : "Text" }
    private var subtitle: String { channel == .email ? "Sends to inbox" : "Sends an SMS" }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? Color.indigo : .secondary)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? Color.indigo : .primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.indigo : Color(.separator), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
