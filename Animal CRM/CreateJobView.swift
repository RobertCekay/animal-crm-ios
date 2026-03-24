//
//  CreateJobView.swift
//  Animal CRM
//
//  Create a new job — 5-section form using shared JobEstimateFormViewModel.
//

import SwiftUI

struct CreateJobView: View {
    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((Job) -> Void)?

    @StateObject private var vm = JobEstimateFormViewModel()
    @State private var showingLeadPicker = false
    @State private var showingPropertyPicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                customerPropertySection
                appointmentSection
                if vm.appointmentEnabled {
                    recurringSection
                }
                notesSection
                lineItemsSection
                settingsSection
            }
            .navigationTitle("New Job")
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
                EstimateLeadPickerView(selectedLead: $vm.selectedLead) { newProperty in
                    if let newProperty {
                        vm.propertySelection = .existing(newProperty)
                    } else {
                        vm.propertySelection = .none
                    }
                    if let id = vm.selectedLead?.id {
                        Task { await vm.loadProperties(for: id) }
                    }
                }
                .environmentObject(api)
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
            Button { showingLeadPicker = true } label: {
                HStack {
                    if let lead = vm.selectedLead {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lead.name).foregroundColor(.primary).fontWeight(.medium)
                            if let phone = lead.phone {
                                Text(phone).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Select customer…").foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }

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
            Toggle("Schedule appointment", isOn: $vm.appointmentEnabled)
            if vm.appointmentEnabled {
                DatePicker("Date", selection: $vm.scheduledDate, displayedComponents: .date)
                DatePicker("Start Time", selection: $vm.scheduledTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $vm.scheduledEndTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Label("Appointment", systemImage: "calendar")
        }
    }

    // MARK: - Section 2b: Recurrence

    @ViewBuilder
    private var recurringSection: some View {
        Section {
            Toggle("Recurring Job", isOn: $vm.isRecurring)
            if vm.isRecurring {
                Picker("Frequency", selection: $vm.recurrenceFrequency) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                DatePicker("End Date", selection: $vm.recurrenceEndDate,
                           in: Date()..., displayedComponents: .date)
                Text("A separate job and invoice will be created for each occurrence.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Recurrence", systemImage: "arrow.clockwise")
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
                Toggle("Send invoice email to customer", isOn: $vm.sendInvoiceOnCreate)

                if vm.appointmentEnabled {
                    Toggle("Send appointment confirmation", isOn: $vm.sendAppointmentOnCreate)

                    Toggle("Send appointment reminder", isOn: $vm.sendAppointmentReminder)
                    if vm.sendAppointmentReminder {
                        Stepper("Days before: \(vm.appointmentReminderDays)",
                                value: $vm.appointmentReminderDays, in: 1...14)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Deposit Required").font(.subheadline)
                    Text("Leave blank if no deposit needed")
                        .font(.caption).foregroundColor(.secondary)
                    HStack {
                        Text("$").foregroundColor(.secondary)
                        TextField("0.00", text: $vm.depositAmount)
                            .keyboardType(.decimalPad)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Assigned Team", systemImage: "person.2.fill")
                        .font(.subheadline)
                    Text("Coming soon")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard vm.validate(isJob: true) else { return }
        vm.isSubmitting = true
        defer { vm.isSubmitting = false }
        let body = vm.buildJobRequest()
        do {
            let job = try await api.createJob(body)
            await MainActor.run {
                onCreated?(job)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CreateJobView()
        .environmentObject(APIService.shared)
}
