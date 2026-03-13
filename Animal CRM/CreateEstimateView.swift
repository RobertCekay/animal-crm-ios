//
//  CreateEstimateView.swift
//  Animal CRM
//
//  Create a new estimate — 5-section form using shared JobEstimateFormViewModel.
//

import SwiftUI

struct CreateEstimateView: View {
    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((Estimate) -> Void)?

    @StateObject private var vm = JobEstimateFormViewModel()
    @State private var showingLeadPicker = false
    @State private var showingPropertyPicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                customerPropertySection
                appointmentSection
                notesSection
                lineItemsSection
                settingsSection
            }
            .navigationTitle("New Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(vm.isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await submit() } } label: {
                        if vm.isSubmitting { ProgressView() } else { Text("Create").bold() }
                    }
                    .disabled(vm.selectedLead == nil || vm.isSubmitting)
                }
            }
            .task { await vm.loadInitialData() }
            .sheet(isPresented: $showingLeadPicker) {
                EstimateLeadPickerView(selectedLead: $vm.selectedLead) {
                    vm.propertySelection = .none
                    if let id = vm.selectedLead?.id {
                        Task { await vm.loadProperties(for: id) }
                    }
                }
                .environmentObject(api)
                .onChange(of: vm.selectedLead) { lead in
                    if let id = lead?.id {
                        Task { await vm.loadProperties(for: id) }
                    }
                }
            }
            .sheet(isPresented: $showingPropertyPicker) {
                if let lead = vm.selectedLead {
                    PropertyPickerView(leadId: lead.id, selection: $vm.propertySelection)
                        .environmentObject(api)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
            .alert("Validation", isPresented: .constant(vm.validationError != nil), actions: {
                Button("OK") { vm.validationError = nil }
            }, message: { Text(vm.validationError ?? "") })
        }
    }

    // MARK: - Section 1: Customer & Property

    @ViewBuilder
    private var customerPropertySection: some View {
        Section {
            // Lead picker
            Button { showingLeadPicker = true } label: {
                HStack {
                    if let lead = vm.selectedLead {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lead.name).foregroundColor(.primary).fontWeight(.medium)
                            if let phone = lead.phone {
                                Text(phone).font(.caption).foregroundColor(.secondary)
                            }
                            if lead.email == nil || lead.email?.isEmpty == true {
                                Label("No email — sending will silently fail", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundColor(.orange)
                            }
                        }
                    } else {
                        Text("Select customer…").foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }

            // Property picker (only after lead selected)
            if vm.selectedLead != nil {
                if vm.propertiesLoading {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Loading locations…").font(.subheadline).foregroundColor(.secondary)
                    }
                } else {
                    Button { showingPropertyPicker = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.propertySelection.displayLabel)
                                    .foregroundColor(vm.propertySelection == .none ? .secondary : .primary)
                                if let sub = vm.propertySelection.displaySubtitle {
                                    Text(sub).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("Select a customer first")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        } header: {
            Label("Customer & Location", systemImage: "person.fill")
        }
    }

    // MARK: - Section 2: Appointment

    @ViewBuilder
    private var appointmentSection: some View {
        Section {
            Toggle("Schedule site visit", isOn: $vm.appointmentEnabled)
            if vm.appointmentEnabled {
                DatePicker("Date", selection: $vm.scheduledDate, displayedComponents: .date)
                DatePicker("Start Time", selection: $vm.scheduledTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $vm.scheduledEndTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Label("Appointment", systemImage: "calendar")
        } footer: {
            if vm.appointmentEnabled {
                Text("Optional site visit or consultation before quoting.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Section 3: Notes

    @ViewBuilder
    private var notesSection: some View {
        Section {
            TextEditor(text: $vm.notes)
                .frame(minHeight: 80)
        } header: {
            Label("Internal Notes", systemImage: "note.text")
        } footer: {
            Text("Visible to your team only — not sent to the customer.")
                .font(.caption)
        }
    }

    // MARK: - Section 4: Line Items

    @ViewBuilder
    private var lineItemsSection: some View {
        Section {
            LineItemsEditorView(items: $vm.lineItems, products: vm.products)
        } header: {
            Label("Line Items", systemImage: "list.bullet.rectangle")
        } footer: {
            if !vm.lineItems.isEmpty {
                Text("Subtotal: \(String(format: "$%.2f", vm.grandTotal))")
            }
        }
    }

    // MARK: - Section 5: Settings

    @ViewBuilder
    private var settingsSection: some View {
        Section {
            DisclosureGroup("Settings", isExpanded: $vm.settingsExpanded) {
                Toggle("Send estimate email to customer", isOn: $vm.sendEstimateOnCreate)
            }
        } footer: {
            if vm.sendEstimateOnCreate {
                Text("Estimate link will be emailed to the customer on creation.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard vm.validate(isJob: false) else { return }
        vm.isSubmitting = true
        defer { vm.isSubmitting = false }
        let body = vm.buildEstimateRequest()
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

// MARK: - Lead picker with "Create New Lead" row (reused from previous implementation)

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
                                Label("Create New Customer", systemImage: "person.badge.plus")
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

// MARK: - Quick Create Lead

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
            .navigationTitle("New Customer")
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
