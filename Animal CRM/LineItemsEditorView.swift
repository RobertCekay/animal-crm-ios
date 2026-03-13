//
//  LineItemsEditorView.swift
//  Animal CRM
//
//  Reusable line-items editor with product catalog picker.
//  Used on Create/Edit Estimate and Create Job forms.
//

import SwiftUI

// MARK: - Editor

struct LineItemsEditorView: View {
    @Binding var items: [LineItemDraft]
    let products: [Product]

    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    var grandTotal: Double { items.reduce(0) { $0 + $1.computedTotal } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach($items) { $item in
                LineItemRow(item: $item, products: products)
                    .padding(.vertical, 8)
                Divider()
            }
            .onDelete { items.remove(atOffsets: $0) }

            Button {
                items.append(LineItemDraft())
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 10)

            if !items.isEmpty {
                HStack {
                    Text("Subtotal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(LineItemsEditorView.currency.string(from: NSNumber(value: grandTotal)) ?? String(format: "$%.2f", grandTotal))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Row

private struct LineItemRow: View {
    @Binding var item: LineItemDraft
    let products: [Product]

    @State private var priceText: String = ""
    @State private var showingPicker = false
    @FocusState private var priceFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Product picker button or description field
            if item.productId == nil && item.description.isEmpty {
                Button {
                    showingPicker = true
                } label: {
                    HStack {
                        Text("Select a product...")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    TextField("Description", text: $item.description)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        showingPicker = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                // Quantity stepper
                HStack(spacing: 6) {
                    Text("Qty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button {
                        if item.quantity > 1 { item.quantity -= 1 }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundColor(item.quantity > 1 ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    Text("\(item.quantity)")
                        .font(.subheadline)
                        .frame(minWidth: 24, alignment: .center)
                    Button {
                        if item.quantity < 999 { item.quantity += 1 }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
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
                        .onChange(of: priceText) { text in
                            if let v = Double(text) {
                                item.unitPrice = v
                            }
                        }
                }

                // Row total
                let total = item.computedTotal
                Text(String(format: "= $%.2f", total))
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
        .sheet(isPresented: $showingPicker) {
            ProductPickerSheet(products: products) { selected in
                if let product = selected {
                    item.productId = product.id
                    item.description = product.name
                    if let price = product.unitPrice {
                        item.unitPrice = price
                        priceText = String(format: "%.2f", price)
                    }
                } else {
                    // Custom — clear product link, keep existing description
                    item.productId = nil
                }
            }
        }
    }
}

// MARK: - Product Picker Sheet

struct ProductPickerSheet: View {
    let products: [Product]
    let onSelect: (Product?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var filtered: [Product] {
        search.isEmpty ? products
            : products.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Button("Custom description (no product)") {
                    onSelect(nil)
                    dismiss()
                }
                .foregroundColor(.secondary)

                ForEach(filtered) { product in
                    Button {
                        onSelect(product)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .foregroundColor(.primary)
                            if let desc = product.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            if let price = product.unitPrice {
                                Text(price, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search products")
            .navigationTitle("Select Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
