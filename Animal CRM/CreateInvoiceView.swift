//
//  CreateInvoiceView.swift
//  Animal CRM
//
//  Creates an invoice from a job directly from the field.
//

import SwiftUI

struct CreateInvoiceView: View {
    let job: Job
    let onCreated: (Invoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isCreating = false
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invoice Preview").font(.headline)
                            if let name = job.customerName {
                                Label(name, systemImage: "person.fill")
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            if !job.lineItems.isEmpty {
                                Divider()
                                ForEach(job.lineItems) { item in
                                    HStack {
                                        Text(item.description ?? "Item").font(.subheadline)
                                        Spacer()
                                        Text(item.formattedTotal).font(.subheadline)
                                    }
                                }
                                Divider()
                                HStack {
                                    Text("Total").font(.headline)
                                    Spacer()
                                    let total = job.lineItems.reduce(0) { $0 + $1.total }
                                    Text(String(format: "$%.2f", total)).font(.headline.bold())
                                }
                            } else {
                                Text("No line items on this job. Invoice will be created empty.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        if let err = errorMessage {
                            Text(err).font(.caption).foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }

                VStack(spacing: 10) {
                    Button {
                        Task { await create(send: false) }
                    } label: {
                        Group {
                            if isCreating { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                            else { Text("Save as Draft").fontWeight(.semibold) }
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color(.systemGray4)).foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    .disabled(isCreating || isSending)
                    .padding(.horizontal)

                    Button {
                        Task { await create(send: true) }
                    } label: {
                        Group {
                            if isSending { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                            else { Text("Save & Send to Customer").fontWeight(.semibold) }
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.blue).foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isCreating || isSending)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Create Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func create(send: Bool) async {
        errorMessage = nil
        if send { isSending = true } else { isCreating = true }
        defer { isCreating = false; isSending = false }
        do {
            let invoice = try await APIService.shared.createJobInvoice(jobId: job.id)
            if send { try? await APIService.shared.sendInvoice(invoiceId: invoice.id) }
            onCreated(invoice)
            dismiss()
        } catch APIError.serverError(let msg) {
            errorMessage = msg
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
