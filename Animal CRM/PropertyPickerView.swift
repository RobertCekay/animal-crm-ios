//
//  PropertyPickerView.swift
//  Animal CRM
//
//  Picker for a lead's service locations (properties).
//  Shows saved properties, "+ New Address", and "No location".
//

import SwiftUI

// MARK: - Result type

enum PropertySelection: Equatable {
    case none
    case existing(Property)
    case newAddress(name: String, address: String, city: String, state: String, zip: String)

    var displayLabel: String {
        switch self {
        case .none: return "No location"
        case .existing(let p): return p.name
        case .newAddress(let name, _, _, _, _): return name.isEmpty ? "New address" : name
        }
    }

    var displaySubtitle: String? {
        switch self {
        case .none: return nil
        case .existing(let p): return p.fullAddress.isEmpty ? nil : p.fullAddress
        case .newAddress(_, let address, let city, let state, let zip):
            let parts = [address, city, state, zip].filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
    }

    static func == (lhs: PropertySelection, rhs: PropertySelection) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case (.existing(let a), .existing(let b)): return a.id == b.id
        case (.newAddress, .newAddress): return true
        default: return false
        }
    }
}

// MARK: - Main Picker Sheet

struct PropertyPickerView: View {
    let leadId: Int
    @Binding var selection: PropertySelection
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var api: APIService

    @State private var properties: [Property] = []
    @State private var isLoading = false
    @State private var showingNewAddress = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading locations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // No location option
                        Button {
                            selection = .none
                            dismiss()
                        } label: {
                            HStack {
                                Label("No specific location", systemImage: "location.slash")
                                    .foregroundColor(.secondary)
                                Spacer()
                                if selection == .none {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }

                        // Saved properties
                        if !properties.isEmpty {
                            Section("Saved Locations") {
                                ForEach(properties) { property in
                                    Button {
                                        selection = .existing(property)
                                        dismiss()
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text(property.name)
                                                        .font(.headline)
                                                        .foregroundColor(.primary)
                                                    if property.primary {
                                                        Text("Primary")
                                                            .font(.caption2).bold()
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 2)
                                                            .background(Color.blue)
                                                            .cornerRadius(4)
                                                    }
                                                }
                                                if !property.fullAddress.isEmpty {
                                                    Text(property.fullAddress)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                            if case .existing(let p) = selection, p.id == property.id {
                                                Image(systemName: "checkmark").foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // New address
                        Section {
                            Button {
                                showingNewAddress = true
                            } label: {
                                Label("New Address...", systemImage: "plus.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Service Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
            .sheet(isPresented: $showingNewAddress) {
                NewPropertySheet(leadId: leadId) { newProp in
                    properties.insert(newProp, at: 0)
                    selection = .existing(newProp)
                    dismiss()
                }
                .environmentObject(api)
            }
        }
        .onAppear { Task { await load() } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            properties = try await api.fetchProperties(leadId: leadId)
            // Auto-select primary if nothing chosen yet
            if selection == .none, let primary = properties.first(where: { $0.primary }) {
                selection = .existing(primary)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - New Property Sheet

struct NewPropertySheet: View {
    let leadId: Int
    let onCreated: (Property) -> Void

    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Location Name") {
                    TextField("e.g. Main House, Rental on Oak St", text: $name)
                }
                Section("Address") {
                    TextField("Street address", text: $address)
                    TextField("Apt, suite, etc. (optional)", text: $addressLine2)
                    TextField("City", text: $city)
                    HStack {
                        TextField("State", text: $state)
                        TextField("ZIP", text: $zip)
                            .keyboardType(.numberPad)
                    }
                }
                Section("Notes (optional)") {
                    TextField("Access instructions, gate code, etc.", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSubmitting { ProgressView() } else { Text("Save").bold() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
        }
    }

    private func save() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let body = CreatePropertyRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            address: address.isEmpty ? nil : address,
            addressLine2: addressLine2.isEmpty ? nil : addressLine2,
            city: city.isEmpty ? nil : city,
            state: state.isEmpty ? nil : state,
            zip: zip.isEmpty ? nil : zip,
            notes: notes.isEmpty ? nil : notes
        )
        do {
            let created = try await api.createProperty(leadId: leadId, body: body)
            await MainActor.run {
                onCreated(created)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
