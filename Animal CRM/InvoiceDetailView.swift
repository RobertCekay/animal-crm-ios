//
//  InvoiceDetailView.swift
//  Animal CRM
//
//  Read-only invoice detail. Invoices are server-managed and mirror job line items.
//

import SwiftUI

struct InvoiceDetailView: View {
    let invoice: Invoice

    @State private var currentInvoice: Invoice
    @State private var showingRecordPayment = false

    init(invoice: Invoice) {
        self.invoice = invoice
        _currentInvoice = State(initialValue: invoice)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentInvoice.number)
                                .font(.title2).bold()
                            if let name = currentInvoice.leadName {
                                Label(name, systemImage: "person.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        InvoiceStatusBadge(status: currentInvoice.status, isPaid: currentInvoice.isPaid)
                    }

                    HStack(spacing: 20) {
                        if let issued = currentInvoice.issuedOn {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Issued").font(.caption).foregroundColor(.secondary)
                                Text(issued.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                            }
                        }
                        if let due = currentInvoice.dueDate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Due").font(.caption).foregroundColor(.secondary)
                                Text(due.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundColor(currentInvoice.isPaid ? .secondary : .red)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Line Items
                if !currentInvoice.lineItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Line Items").font(.headline)
                        ForEach(currentInvoice.lineItems) { item in
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
                            if item.id != currentInvoice.lineItems.last?.id { Divider() }
                        }
                        Divider()
                        HStack {
                            Text("Total").font(.headline)
                            Spacer()
                            Text(currentInvoice.formattedTotal).font(.title3).bold()
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                }

                // Payment Status
                VStack(alignment: .leading, spacing: 10) {
                    Text("Payment").font(.headline)
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(currentInvoice.formattedTotal).fontWeight(.semibold)
                    }
                    if currentInvoice.isPaid {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                            Text("Paid in full").foregroundColor(.green).fontWeight(.semibold)
                            Spacer()
                            if let paidAt = currentInvoice.paidAt {
                                Text(paidAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Text("Amount Due").foregroundColor(.red)
                            Spacer()
                            Text(currentInvoice.formattedRemaining)
                                .foregroundColor(.red).fontWeight(.bold)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)

                // Record Payment
                if !currentInvoice.isPaid {
                    Button { showingRecordPayment = true } label: {
                        Label("Record Payment", systemImage: "dollarsign.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRecordPayment) {
            RecordPaymentView(invoice: currentInvoice) {
                // After payment recorded, refresh would require refetch — for now just mark optimistically
            }
        }
    }
}

// MARK: - Status Badge

private struct InvoiceStatusBadge: View {
    let status: String
    let isPaid: Bool

    var label: String {
        switch status {
        case "paid": return "Paid"
        case "overdue": return "Overdue"
        case "sent": return "Sent"
        default: return "Draft"
        }
    }

    var color: Color {
        switch status {
        case "paid": return .green
        case "overdue": return .red
        case "sent": return .blue
        default: return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption).fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color)
            .cornerRadius(8)
    }
}
