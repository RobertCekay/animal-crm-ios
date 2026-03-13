//
//  EditEstimateView.swift
//  Animal CRM
//
//  Edit an existing estimate — pre-populated PATCH form
//

import SwiftUI

struct EditEstimateView: View {
    let estimate: Estimate
    let onUpdated: (Estimate) -> Void

    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var propertySelection: PropertySelection
    @State private var lineItems: [LineItemDraft]
    @State private var notes: String

    @State private var showingPropertyPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var grandTotal: Double { lineItems.reduce(0) { $0 + $1.total } }

    init(estimate: Estimate, onUpdated: @escaping (Estimate) -> Void) {
        self.estimate = estimate
        self.onUpdated = onUpdated

        // Pre-populate property selection
        if let name = estimate.propertyName, let id = estimate.propertyId {
            let property = Property(
                id: id,
                leadId: estimate.leadId,
                name: name,
                address: estimate.propertyAddress,
                addressLine2: nil,
                city: estimate.propertyCity,
                state: estimate.propertyState,
                zip: estimate.propertyZip,
                country: nil,
                notes: nil,
                primary: false,
                createdAt: estimate.createdAt
            )
            _propertySelection = State(initialValue: .existing(property))
        } else {
            _propertySelection = State(initialValue: .none)
        }

        // Pre-populate line items from existing
        _lineItems = State(initialValue: estimate.lineItems.map { item in
            var draft = LineItemDraft()
            draft.description = item.description ?? ""
            draft.quantity = item.quantity
            draft.unitPrice = item.unitPrice
            return draft
        })

        _notes = State(initialValue: estimate.notes ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                // Lead (read-only — cannot change after creation)
                Section("Customer") {
                    HStack {
                        Label(estimate.leadName ?? "Unknown", systemImage: "person.fill")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Cannot change")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Service Location
                Section("Service Location") {
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

                // Line Items — always sent on PATCH to replace
                Section {
                    LineItemsEditorView(items: $lineItems)
                } header: { Text("Line Items") }
                  footer: {
                    if !lineItems.isEmpty {
                        Text("Total: \(String(format: "$%.2f", grandTotal))")
                    }
                    Text("Saving will replace all existing line items.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Edit \(estimate.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await save() } } label: {
                        if isSubmitting { ProgressView() } else { Text("Save").bold() }
                    }
                    .disabled(isSubmitting)
                }
            }
            .sheet(isPresented: $showingPropertyPicker) {
                PropertyPickerView(leadId: estimate.leadId, selection: $propertySelection)
                    .environmentObject(api)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
        }
    }

    private func save() async {
        isSubmitting = true
        defer { isSubmitting = false }

        var propertyId: Int? = nil
        if case .existing(let p) = propertySelection { propertyId = p.id }

        // Always send lineItems so server replaces them correctly
        let reqItems = lineItems
            .filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.toRequest() }

        let body = UpdateEstimateRequest(
            notes: notes.isEmpty ? nil : notes,
            propertyId: propertyId,
            lineItems: reqItems
        )

        do {
            let updated = try await api.updateEstimate(id: estimate.id, body: body)
            await MainActor.run {
                onUpdated(updated)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
