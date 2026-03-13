//
//  CreateEstimateView.swift
//  Animal CRM
//
//  Multi-step create estimate: lead → location → line items → notes
//

import SwiftUI

struct CreateEstimateView: View {
    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((Estimate) -> Void)?

    @State private var selectedLead: Lead?
    @State private var propertySelection: PropertySelection = .none
    @State private var lineItems: [LineItemDraft] = []
    @State private var notes = ""

    @State private var showingLeadPicker = false
    @State private var showingPropertyPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var grandTotal: Double { lineItems.reduce(0) { $0 + $1.total } }

    var body: some View {
        NavigationView {
            Form {

                // ── Lead ────────────────────────────────────────────
                Section {
                    Button { showingLeadPicker = true } label: {
                        HStack {
                            if let lead = selectedLead {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lead.name).foregroundColor(.primary).fontWeight(.medium)
                                    if let phone = lead.phone {
                                        Text(phone).font(.caption).foregroundColor(.secondary)
                                    }
                                    if lead.email == nil || lead.email?.isEmpty == true {
                                        Label("No email — sending will silently fail", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            } else {
                                Text("Select a lead...").foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                } header: { Text("Customer (Required)") }

                // ── Service Location ────────────────────────────────
                Section {
                    if selectedLead == nil {
                        Text("Select a customer first")
                            .font(.subheadline).foregroundColor(.secondary)
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
                } header: { Text("Service Location") }

                // ── Line Items ──────────────────────────────────────
                Section {
                    LineItemsEditorView(items: $lineItems)
                } header: { Text("Line Items") }
                  footer: {
                    if !lineItems.isEmpty {
                        Text("Total: \(String(format: "$%.2f", grandTotal))")
                    }
                }

                // ── Notes ───────────────────────────────────────────
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Estimate")
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
                EstimateLeadPickerView(selectedLead: $selectedLead) {
                    propertySelection = .none
                }
                .environmentObject(api)
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

        var propertyId: Int? = nil
        if case .existing(let p) = propertySelection { propertyId = p.id }

        let reqItems = lineItems
            .filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.toRequest() }

        let body = CreateEstimateRequest(
            leadId: lead.id,
            propertyId: propertyId,
            notes: notes.isEmpty ? nil : notes,
            lineItems: reqItems.isEmpty ? nil : reqItems
        )

        do {
            let estimate = try await api.createEstimate(body)
            await MainActor.run {
                onCreated?(estimate)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Lead picker with "Create New Lead" row

struct EstimateLeadPickerView: View {
    @Binding var selectedLead: Lead?
    let onLeadChanged: () -> Void

    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var leads: [Lead] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var showingNewLead = false
    @State private var errorMessage: String?

    var filtered: [Lead] {
        search.isEmpty ? leads : leads.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading...").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered) { lead in
                            Button {
                                selectedLead = lead
                                onLeadChanged()
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(lead.name).font(.headline).foregroundColor(.primary)
                                        if let phone = lead.phone {
                                            Text(phone).font(.caption).foregroundColor(.secondary)
                                        }
                                        if lead.email == nil || lead.email?.isEmpty == true {
                                            Text("No email").font(.caption).foregroundColor(.orange)
                                        }
                                    }
                                    Spacer()
                                    if selectedLead?.id == lead.id {
                                        Image(systemName: "checkmark").foregroundColor(.blue)
                                    }
                                }
                            }
                        }

                        Section {
                            Button { showingNewLead = true } label: {
                                Label("Create New Lead", systemImage: "person.badge.plus")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Select Customer")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search by name")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewLead) {
                QuickCreateLeadView { newLead in
                    leads.insert(newLead, at: 0)
                    selectedLead = newLead
                    onLeadChanged()
                    dismiss()
                }
                .environmentObject(api)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
        }
        .onAppear { Task { await load() } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { leads = try await api.fetchLeads() }
        catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Quick Create Lead (name, phone, email only)

struct QuickCreateLeadView: View {
    let onCreated: (Lead) -> Void

    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Contact") {
                    TextField("Full name", text: $name)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("New Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await save() } } label: {
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
        do {
            let lead = try await api.createLead(
                name: name.trimmingCharacters(in: .whitespaces),
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                address: nil, notes: nil
            )
            await MainActor.run {
                onCreated(lead)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CreateEstimateView()
        .environmentObject(APIService.shared)
}
