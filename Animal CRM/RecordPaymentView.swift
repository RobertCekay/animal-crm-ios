//
//  RecordPaymentView.swift
//  Animal CRM
//
//  Record a manual cash/check payment on an invoice.
//

import SwiftUI

struct RecordPaymentView: View {
    let invoice: Invoice
    let onRecorded: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String
    @State private var selectedMethod = "cash"
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let methods = ["cash", "check", "venmo", "zelle", "other"]

    init(invoice: Invoice, onRecorded: @escaping () -> Void) {
        self.invoice = invoice
        self.onRecorded = onRecorded
        let balance = invoice.remainingAmount ?? invoice.totalAmount
        _amountText = State(initialValue: String(format: "%.2f", balance))
    }

    var amount: Double { Double(amountText) ?? 0 }
    var canSave: Bool { amount > 0 && !isSaving }

    var body: some View {
        NavigationView {
            Form {
                Section("Amount") {
                    HStack {
                        Text("$").foregroundColor(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Payment Method") {
                    Picker("Method", selection: $selectedMethod) {
                        ForEach(methods, id: \.self) { m in
                            Text(m.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Note (optional)") {
                    TextField("e.g. Check #1234", text: $note)
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Record") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await APIService.shared.recordPayment(
                invoiceId: invoice.id,
                amount: amount,
                method: selectedMethod,
                note: note.isEmpty ? nil : note
            )
            onRecorded()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
