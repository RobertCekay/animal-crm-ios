//
//  LineItemsEditorView.swift
//  Animal CRM
//
//  Reusable line-items editor. Used on Create/Edit Estimate and Create Job forms.
//

import SwiftUI

// MARK: - Editor (placed inside a Form Section)

struct LineItemsEditorView: View {
    @Binding var items: [LineItemDraft]
    let products: [Product]   // kept for API compatibility; sheet does live search

    @State private var showingAdd = false
    @State private var editingDraft: LineItemDraft?

    private static let currency: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .currency; f.locale = .init(identifier: "en_US"); return f
    }()

    var grandTotal: Double { items.reduce(0) { $0 + $1.computedTotal } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                LineItemDisplayRow(item: item) {
                    editingDraft = item
                } onDelete: {
                    items.removeAll { $0.id == item.id }
                }
                Divider()
            }

            Button {
                showingAdd = true
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 10)

            if !items.isEmpty {
                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(Self.currency.string(from: NSNumber(value: grandTotal)) ?? String(format: "$%.2f", grandTotal))
                        .font(.headline.bold())
                }
                .padding(.top, 4)
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddLineItemSheet(existingDraft: nil) { newDraft in
                items.append(newDraft)
            }
        }
        .sheet(item: $editingDraft) { draft in
            AddLineItemSheet(existingDraft: draft) { updated in
                if let idx = items.firstIndex(where: { $0.id == draft.id }) {
                    items[idx] = updated
                }
            }
        }
    }
}

// MARK: - Display Row

private struct LineItemDisplayRow: View {
    let item: LineItemDraft
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.description.isEmpty ? "Unnamed item" : item.description)
                    .font(.subheadline.bold())
                    .foregroundColor(item.description.isEmpty ? .secondary : .primary)
                Text("\(item.quantity) × \(String(format: "$%.2f", item.unitPrice))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: "$%.2f", item.computedTotal))
                .font(.subheadline.bold())
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

// MARK: - Add / Edit Sheet

struct AddLineItemSheet: View {
    let existingDraft: LineItemDraft?
    let onAdd: (LineItemDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0          // 0 = Products, 1 = Custom
    @State private var selectedProduct: Product?

    // Product search
    @State private var searchText = ""
    @State private var searchResults: [Product] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    // Shared form fields
    @State private var description = ""
    @State private var quantity = 1
    @State private var unitPriceText = ""
    @State private var unitPrice: Double = 0

    // Save-as-product (custom mode only)
    @State private var saveAsProduct = false
    @State private var productName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var isEditing: Bool { existingDraft != nil }

    var canAdd: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty && unitPrice > 0
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // Tab picker (hidden when editing)
                if !isEditing {
                    Picker("Mode", selection: $selectedTab) {
                        Text("Products").tag(0)
                        Text("Custom Item").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                }

                // Content
                if selectedTab == 0 && !isEditing {
                    productTab
                } else {
                    customTab
                }

                // Error + Add button
                VStack(spacing: 8) {
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        Task { await commitItem() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isEditing ? "Save Changes" : "Add Item")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canAdd ? Color.blue : Color(.systemGray4))
                        .foregroundColor(canAdd ? .white : Color(.systemGray))
                        .cornerRadius(12)
                    }
                    .disabled(!canAdd || isSaving)
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { prefill() }
    }

    // MARK: - Products Tab

    @ViewBuilder
    private var productTab: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search products...", text: $searchText)
                    .onChange(of: searchText) { q in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            await performSearch(query: q)
                        }
                    }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if isSearching {
                ProgressView().padding().frame(maxWidth: .infinity)
            }

            if !searchResults.isEmpty {
                List(searchResults) { product in
                    Button {
                        applyProduct(product)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if let desc = product.description, !desc.isEmpty {
                                    Text(desc).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            if let price = product.unitPrice {
                                Text(String(format: "$%.2f", price))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if selectedProduct?.id == product.id {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            } else if !isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "tag.slash").font(.system(size: 36)).foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Search your product catalog" : "No products found")
                        .foregroundColor(.secondary)
                    Button("Use custom item instead") { selectedTab = 1 }
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                Spacer()
            }

            // Adjustment fields shown after a product is selected
            if selectedProduct != nil {
                Divider()
                VStack(spacing: 0) {
                    formFields
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    // MARK: - Custom Tab

    @ViewBuilder
    private var customTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                formFields
                    .padding(.top, 8)

                // Save as product
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Save as product for reuse", isOn: $saveAsProduct)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    if saveAsProduct {
                        Divider()
                        HStack {
                            Text("Product name")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                        TextField("Product name", text: $productName)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        Text("Will be added to your catalog for future jobs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
                .padding()
            }
        }
    }

    // MARK: - Shared Form Fields

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Description").font(.subheadline).foregroundColor(.secondary).frame(width: 90, alignment: .leading)
                TextField("Item description", text: $description)
                    .font(.subheadline)
            }
            .padding()
            Divider().padding(.leading)

            HStack {
                Text("Quantity").font(.subheadline).foregroundColor(.secondary).frame(width: 90, alignment: .leading)
                Stepper("\(quantity)", value: $quantity, in: 1...999)
            }
            .padding()
            Divider().padding(.leading)

            HStack {
                Text("Unit Price").font(.subheadline).foregroundColor(.secondary).frame(width: 90, alignment: .leading)
                Text("$").foregroundColor(.secondary)
                TextField("0.00", text: $unitPriceText)
                    .keyboardType(.decimalPad)
                    .onChange(of: unitPriceText) { v in
                        unitPrice = Double(v) ?? unitPrice
                    }
            }
            .padding()

            if unitPrice > 0 {
                Divider().padding(.leading)
                HStack {
                    Text("Row Total").font(.subheadline).foregroundColor(.secondary).frame(width: 90, alignment: .leading)
                    Text(String(format: "$%.2f", Double(quantity) * unitPrice))
                        .font(.subheadline.bold())
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
        .padding()
    }

    // MARK: - Helpers

    private func prefill() {
        if let draft = existingDraft {
            description = draft.description
            quantity = draft.quantity
            unitPrice = draft.unitPrice
            unitPriceText = draft.unitPrice > 0 ? String(format: "%.2f", draft.unitPrice) : ""
            selectedTab = draft.productId != nil ? 0 : 1
        } else {
            Task { await performSearch(query: "") }
        }
    }

    private func applyProduct(_ product: Product) {
        selectedProduct = product
        description = product.name
        if let price = product.unitPrice {
            unitPrice = price
            unitPriceText = String(format: "%.2f", price)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        searchResults = (try? await APIService.shared.fetchProducts(query: query.isEmpty ? nil : query)) ?? []
        isSearching = false
    }

    private func commitItem() async {
        var productId = selectedProduct?.id ?? existingDraft?.productId

        if saveAsProduct && selectedTab == 1 && !description.isEmpty {
            isSaving = true
            let name = productName.trimmingCharacters(in: .whitespaces).isEmpty ? description : productName
            do {
                let saved = try await APIService.shared.createProduct(name: name, description: nil, unitPrice: unitPrice)
                productId = saved.id
            } catch {
                errorMessage = "Couldn't save product: \(error.localizedDescription)"
                isSaving = false
                return
            }
            isSaving = false
        }

        let draft = LineItemDraft(
            id: existingDraft?.id ?? UUID(),
            productId: productId,
            description: description.trimmingCharacters(in: .whitespaces),
            quantity: quantity,
            unitPrice: unitPrice
        )
        onAdd(draft)
        dismiss()
    }
}
