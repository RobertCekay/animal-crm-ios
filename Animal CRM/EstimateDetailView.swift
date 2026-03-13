//
//  EstimateDetailView.swift
//  Animal CRM
//
//  Full estimate detail: header, location, line items, timeline, contextual actions
//

import SwiftUI

struct EstimateDetailView: View {
    let estimate: Estimate

    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var currentEstimate: Estimate
    @State private var isSending = false
    @State private var isConverting = false
    @State private var showingEdit = false
    @State private var convertedJob: Job?
    @State private var navigateToJob = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    init(estimate: Estimate) {
        self.estimate = estimate
        _currentEstimate = State(initialValue: estimate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentEstimate.number)
                                .font(.title2).bold()
                            Text("Created \(currentEstimate.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        EstimateStatusBadge(status: currentEstimate.status)
                    }
                    if let name = currentEstimate.leadName {
                        Label(name, systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // ── Service Location ────────────────────────────────
                Card {
                    Text("Service Location").font(.headline)
                    if let name = currentEstimate.propertyName {
                        Label(name, systemImage: "house.fill")
                            .font(.subheadline).fontWeight(.semibold)
                        let addr = currentEstimate.formattedPropertyAddress
                        if !addr.isEmpty {
                            Text(addr)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No location set")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // ── Line Items ──────────────────────────────────────
                Card {
                    Text("Line Items").font(.headline)
                    if currentEstimate.lineItems.isEmpty {
                        Text("No line items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(currentEstimate.lineItems) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.description ?? "Item")
                                        .font(.subheadline)
                                    Text("\(item.quantity) × \(String(format: "$%.2f", item.unitPrice))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(item.formattedTotal)
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            if item.id != currentEstimate.lineItems.last?.id { Divider() }
                        }
                        Divider()
                        HStack {
                            Text("Total").font(.headline)
                            Spacer()
                            Text(currentEstimate.formattedTotal).font(.title3).bold()
                        }
                    }
                }

                // ── Notes ───────────────────────────────────────────
                if let notes = currentEstimate.notes, !notes.isEmpty {
                    Card {
                        Text("Notes").font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                // ── Timeline ────────────────────────────────────────
                Card {
                    Text("Timeline").font(.headline)
                    TimelineRow(label: "Created",  date: currentEstimate.createdAt)
                    Divider()
                    TimelineRow(label: "Sent",     date: currentEstimate.sentToCustomerAt)
                    Divider()
                    TimelineRow(label: "Accepted", date: currentEstimate.acceptedByCustomerAt)
                    if let d = currentEstimate.declinedAt {
                        Divider()
                        TimelineRow(label: "Declined", date: d)
                    }
                }

                // ── Actions ─────────────────────────────────────────
                VStack(spacing: 12) {
                    let status = currentEstimate.status

                    // Send / Resend
                    if status == "open" || status == "sent" {
                        let hasEmail = !(currentEstimate.leadName?.isEmpty ?? true)  // proxy — server guards the real check
                        EstimateActionButton(
                            label: status == "sent" ? "Resend to Customer" : "Send to Customer",
                            icon: "envelope.fill",
                            color: .blue,
                            isLoading: isSending
                        ) { Task { await sendToCustomer() } }

                        if currentEstimate.leadName != nil {
                            // We can't check lead.email from the estimate model — show advisory
                        }
                        let _ = hasEmail  // suppress warning
                    }

                    // Edit
                    if status == "open" || status == "sent" || status == "declined" {
                        Button { showingEdit = true } label: {
                            Label("Edit Estimate", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                    }

                    // Convert to Job — always allowed per spec
                    EstimateActionButton(
                        label: "Convert to Job",
                        icon: "briefcase.fill",
                        color: status == "accepted" ? .green : .orange,
                        isLoading: isConverting
                    ) { Task { await convertToJob() } }
                }

                // Hidden job nav
                NavigationLink(
                    destination: Group { if let j = convertedJob { JobDetailView(job: j) } },
                    isActive: $navigateToJob
                ) { EmptyView() }
            }
            .padding()
        }
        .navigationTitle("Estimate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSending || isConverting { ProgressView() }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditEstimateView(estimate: currentEstimate) { updated in
                currentEstimate = updated
            }
            .environmentObject(api)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
        .alert("Sent", isPresented: .constant(successMessage != nil), actions: {
            Button("OK") { successMessage = nil }
        }, message: { Text(successMessage ?? "") })
        .onAppear { Task { await refresh() } }
    }

    // MARK: - Actions

    private func refresh() async {
        if let updated = try? await api.fetchEstimate(id: currentEstimate.id) {
            currentEstimate = updated
        }
    }

    private func sendToCustomer() async {
        isSending = true
        defer { isSending = false }
        do {
            currentEstimate = try await api.sendEstimateToCustomer(id: currentEstimate.id)
            successMessage = "Estimate sent to \(currentEstimate.leadName ?? "customer")."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func convertToJob() async {
        isConverting = true
        defer { isConverting = false }
        do {
            let job = try await api.convertEstimateToJob(id: currentEstimate.id)
            await MainActor.run {
                convertedJob = job
                navigateToJob = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Sub-views

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

private struct TimelineRow: View {
    let label: String
    let date: Date?

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            if let d = date {
                Text(d.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct EstimateActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading { ProgressView().scaleEffect(0.85).padding(.trailing, 4) }
                Label(isLoading ? "Working..." : label, systemImage: icon)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isLoading)
    }
}

#Preview {
    // Create a mock Estimate using JSON decoding
    let jsonData = """
    {
        "id": 1,
        "number": "EST-00001",
        "status": "open",
        "lead_id": 1,
        "lead_name": "Jane Smith",
        "notes": "Replace HVAC",
        "total_amount": 2400,
        "line_items": [],
        "property_id": null,
        "property_name": "Main House",
        "property_address": "123 Oak St",
        "property_city": "Nashville",
        "property_state": "TN",
        "property_zip": "37201",
        "sent_to_customer_at": null,
        "accepted_by_customer_at": null,
        "declined_at": null,
        "created_at": "2024-01-15T10:00:00Z",
        "updated_at": "2024-01-15T10:00:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let estimate = try! decoder.decode(Estimate.self, from: jsonData)
    
    return NavigationView {
        EstimateDetailView(estimate: estimate)
            .environmentObject(APIService.shared)
    }
}
