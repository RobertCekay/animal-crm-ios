//
//  CreateJobView.swift
//  Animal CRM
//
//  Create a new job — lead, service location, schedule, line items
//

import SwiftUI

struct CreateJobView: View {
    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((Job) -> Void)?

    @State private var selectedLead: Lead?
    @State private var propertySelection: PropertySelection = .none
    @State private var notes = ""
    @State private var scheduleEnabled = false
    @State private var scheduledDate = Date()
    @State private var scheduledTime = Date()
    @State private var lineItems: [LineItemDraft] = []

    @State private var showingLeadPicker = false
    @State private var showingPropertyPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let dateFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var grandTotal: Double { lineItems.reduce(0) { $0 + $1.total } }

    var body: some View {
        NavigationView {
            Form {
                // Lead
                Section("Lead (Required)") {
                    Button { showingLeadPicker = true } label: {
                        HStack {
                            if let lead = selectedLead {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lead.name).foregroundColor(.primary)
                                    if let phone = lead.phone {
                                        Text(phone).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Text("Select a lead...").foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                }

                // Service Location
                Section("Service Location") {
                    if selectedLead == nil {
                        Text("Select a lead first")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        Button { showingPropertyPicker = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(propertySelection.displayLabel)
                                        .foregroundColor(propertySelection == .none ? .secondary : .primary)
                                    if let sub = propertySelection.displaySubtitle {
                                        Text(sub).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                // Schedule
                Section {
                    Toggle("Schedule appointment", isOn: $scheduleEnabled)
                    if scheduleEnabled {
                        DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                        DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    }
                } header: { Text("Schedule") }

                // Line Items
                Section {
                    LineItemsEditorView(items: $lineItems)
                } header: {
                    Text("Line Items")
                } footer: {
                    if !lineItems.isEmpty {
                        Text("Total: \(String(format: "$%.2f", grandTotal))")
                    }
                }
            }
            .navigationTitle("New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await submit() } } label: {
                        if isSubmitting { ProgressView() } else { Text("Create").bold() }
                    }
                    .disabled(selectedLead == nil || isSubmitting)
                }
            }
            .sheet(isPresented: $showingLeadPicker) {
                LeadPickerView(selectedLead: $selectedLead)
                    .environmentObject(api)
                    .onChange(of: selectedLead) { _ in
                        // Reset location when lead changes
                        propertySelection = .none
                    }
            }
            .sheet(isPresented: $showingPropertyPicker) {
                if let lead = selectedLead {
                    PropertyPickerView(leadId: lead.id, selection: $propertySelection)
                        .environmentObject(api)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
        }
    }

    private func submit() async {
        guard let lead = selectedLead else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let reqItems = lineItems
            .filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.toRequest() }

        // Resolve property / address from selection
        var propertyId: Int? = nil
        var freeAddress: String? = nil

        switch propertySelection {
        case .existing(let p):
            propertyId = p.id
        case .newAddress(_, let addr, let city, let state, let zip):
            let parts = [addr, city, state, zip].filter { !$0.isEmpty }
            freeAddress = parts.isEmpty ? nil : parts.joined(separator: ", ")
        case .none:
            break
        }

        let body = CreateJobRequest(
            leadId: lead.id,
            propertyId: propertyId,
            notes: notes.isEmpty ? nil : notes,
            address: freeAddress,
            scheduledDate: scheduleEnabled ? dateFmt.string(from: scheduledDate) : nil,
            scheduledTime: scheduleEnabled ? timeFmt.string(from: scheduledTime) : nil,
            lineItems: reqItems.isEmpty ? nil : reqItems
        )

        do {
            let newJob = try await api.createJob(body)
            await MainActor.run {
                dismiss()
                onCreated?(newJob)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CreateJobView()
        .environmentObject(APIService.shared)
}
