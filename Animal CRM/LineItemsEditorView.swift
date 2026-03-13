//
//  LineItemsEditorView.swift
//  Animal CRM
//
//  Reusable line-items editor for jobs and estimates
//

import SwiftUI

struct LineItemsEditorView: View {
    @Binding var items: [LineItemDraft]

    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    var grandTotal: Double { items.reduce(0) { $0 + $1.total } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach($items) { $item in
                LineItemRow(item: $item)
                    .padding(.vertical, 8)
                Divider()
            }
            .onDelete { items.remove(atOffsets: $0) }

            Button {
                items.append(LineItemDraft())
            } label: {
                Label("Add Line Item", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 10)

            if !items.isEmpty {
                HStack {
                    Spacer()
                    Text("Total")
                        .font(.headline)
                    Text(String(format: "$%.2f", grandTotal))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.top, 4)
            }
        }
    }
}

struct LineItemRow: View {
    @Binding var item: LineItemDraft

    @State private var priceText: String = ""
    @FocusState private var priceFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Description", text: $item.description)
                .font(.subheadline)

            HStack(spacing: 12) {
                // Quantity stepper
                HStack(spacing: 4) {
                    Text("Qty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(item.quantity)", value: $item.quantity, in: 1...999)
                        .labelsHidden()
                    Text("\(item.quantity)")
                        .font(.subheadline)
                        .frame(minWidth: 24)
                }

                Spacer()

                // Unit price
                HStack(spacing: 4) {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0.00", text: $priceText)
                        .keyboardType(.decimalPad)
                        .frame(width: 72)
                        .multilineTextAlignment(.trailing)
                        .focused($priceFocused)
                        .onChange(of: priceFocused) { focused in
                            if !focused {
                                item.unitPrice = Double(priceText) ?? item.unitPrice
                            }
                        }
                }

                Text(String(format: "= $%.2f", item.total))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if item.unitPrice > 0 {
                priceText = String(format: "%.2f", item.unitPrice)
            }
        }
    }
}
