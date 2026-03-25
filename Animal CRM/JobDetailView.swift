//
//  JobDetailView.swift
//  Animal CRM
//
//  Detailed view of a single job with actions
//

import SwiftUI

struct JobDetailView: View {
    let job: Job
    @StateObject private var apiService = APIService.shared
    @State private var currentJob: Job
    @State private var showingPhotoPicker = false
    @State private var errorMessage: String?
    @State private var invoice: Invoice?
    @State private var showingInvoice = false
    @State private var navigateToConversation: Lead?
    @State private var isNavigatingToConversation = false
    @ObservedObject private var callManager = CallManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingRecurringInstances = false
    @State private var recurringInstances: RecurringInstancesResponse?
    @State private var isLoadingInstances = false
    @State private var isSendingOnMyWay = false
    @State private var onMyWaySent = false
    @State private var showingReviewSheet = false
    @State private var reviewAlertMessage: String?
    @State private var reviewToast: String?
    @State private var updatedContactLead: Lead?
    @State private var showingCreateInvoice = false
    @State private var showingAddAppointment = false
    @State private var appointments: [Appointment] = []
    @State private var editingAppointment: Appointment?

    init(job: Job) {
        self.job = job
        _currentJob = State(initialValue: job)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(currentJob.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        StatusBadge(status: currentJob.status)
                    }

                    if let date = currentJob.scheduledDate {
                        Label(date.formatted(date: .abbreviated, time: .omitted),
                              systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let time = currentJob.scheduledTime {
                        Label(time, systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Quick Actions
                if currentJob.leadId != nil && currentJob.customerPhone != nil {
                    Button {
                        Task { await sendOnMyWay() }
                    } label: {
                        Group {
                            if isSendingOnMyWay {
                                ProgressView().scaleEffect(0.85)
                            } else if onMyWaySent {
                                Label("Sent!", systemImage: "checkmark.circle.fill")
                            } else {
                                Label("On My Way", systemImage: "car.fill")
                            }
                        }
                        .font(.subheadline).fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(onMyWaySent ? Color.green : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isSendingOnMyWay || onMyWaySent)
                }

                // Recurring banner (child instance)
                if currentJob.isChildInstance {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        Text("Part of a recurring series")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                        if let parentId = currentJob.parentJobId {
                            Text("#\(parentId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
                }

                // Recurring schedule (parent job)
                if currentJob.isRecurring && !currentJob.isChildInstance {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Recurring Schedule", systemImage: "arrow.clockwise")
                            .font(.headline)
                        if let label = currentJob.recurrenceLabel {
                            Text(label)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let endDate = currentJob.recurrenceEndDate {
                            Text("Until \(endDate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let count = currentJob.recurringInstanceCount {
                            Text("\(count) total occurrences")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Button {
                            showingRecurringInstances = true
                            Task { await loadRecurringInstances() }
                        } label: {
                            if isLoadingInstances {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.8)
                                    Text("Loading…")
                                }
                            } else {
                                Label("View all occurrences", systemImage: "list.bullet")
                            }
                        }
                        .font(.subheadline)
                        .disabled(isLoadingInstances)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                }

                // Customer Info
                if currentJob.customerName != nil || currentJob.customerPhone != nil || currentJob.customerEmail != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Customer")
                            .font(.headline)

                        if let lead = jobLead {
                            NavigationLink(destination:
                                ContactDetailView(
                                    lead: updatedContactLead ?? lead,
                                    onUpdated: { updated in updatedContactLead = updated },
                                    onDeleted: { _ in }
                                )
                                .environmentObject(APIService.shared)
                            ) {
                                Label(
                                    updatedContactLead?.name ?? lead.name,
                                    systemImage: "person"
                                )
                                .foregroundColor(.primary)
                            }
                        } else if let name = currentJob.customerName {
                            Label(name, systemImage: "person")
                        }

                        // Hidden navigation link for conversation
                        NavigationLink(
                            destination: navigateToConversation.map { LeadConversationView(lead: $0) },
                            isActive: $isNavigatingToConversation
                        ) { EmptyView() }.hidden()

                        HStack(spacing: 12) {
                            if let phone = currentJob.customerPhone {
                                Button {
                                    callViaTwilio(phone)
                                } label: {
                                    Label("Call", systemImage: "phone.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.green)
                                        .cornerRadius(8)
                                }

                                if jobLead != nil {
                                    Button { openConversation() } label: {
                                        Label("Text", systemImage: "message.fill")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                }
                            }

                            if currentJob.customerEmail != nil, jobLead != nil {
                                Button { openConversation() } label: {
                                    Label("Email", systemImage: "envelope.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                }

                // Photos
                VStack(alignment: .leading, spacing: 0) {
                    JobPhotosView(jobId: currentJob.id)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5)

                // Checklists
                VStack(alignment: .leading, spacing: 0) {
                    JobChecklistView(jobId: currentJob.id)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5)

                // Appointments
                AppointmentsSectionView(
                    jobId: currentJob.id,
                    appointments: $appointments,
                    onAdd: { showingAddAppointment = true },
                    onEdit: { appt in editingAppointment = appt },
                    onDelete: { appt in Task { await deleteAppointment(appt) } }
                )
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5)

                // Location
                VStack(alignment: .leading, spacing: 12) {
                    Text("Location")
                        .font(.headline)

                    if let name = currentJob.propertyName {
                        Label(name, systemImage: "house.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if !currentJob.formattedAddress.isEmpty {
                        Label(currentJob.formattedAddress, systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        Button(action: { openMaps() }) {
                            Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .font(.subheadline).fontWeight(.medium)
                        }
                    } else if currentJob.propertyId != nil {
                        Label("Address on file", systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Label("No location set", systemImage: "mappin.slash")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5)

                // Notes
                if let notes = currentJob.notes {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                }

                // Line Items (read-only)
                if !currentJob.lineItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Line Items")
                            .font(.headline)
                        ForEach(currentJob.lineItems) { item in
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
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            if item.id != currentJob.lineItems.last?.id { Divider() }
                        }
                        Divider()
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            let total = currentJob.lineItems.reduce(0) { $0 + $1.total }
                            Text(String(format: "$%.2f", total))
                                .font(.title3).bold()
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                }

                // Amount + paid badge
                if let amount = currentJob.formattedAmount {
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(amount)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(currentJob.isPaid ? .green : .primary)
                        if currentJob.isPaid {
                            Text("PAID")
                                .font(.caption).bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(6)
                        } else {
                            Text("UNPAID")
                                .font(.caption).bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Actions
                VStack(spacing: 12) {
                    // Invoice
                    if let inv = invoice {
                        NavigationLink(destination: InvoiceDetailView(invoice: inv)) {
                            Label(inv.isPaid ? "Invoice (Paid)" : "View Invoice",
                                  systemImage: "doc.text.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(inv.isPaid ? Color.green : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }

                    // Create Invoice
                    if invoice == nil {
                        Button { showingCreateInvoice = true } label: {
                            Label("Create Invoice", systemImage: "doc.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }

                    // Photo upload
                    Button(action: { showingPhotoPicker = true }) {
                        Label("Add Photos", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    // Request Review
                    Button {
                        handleReviewButtonTap()
                    } label: {
                        Label("Request Review", systemImage: "star.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.95, green: 0.70, blue: 0.05))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }

                // Error
                if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
        }

        // Toast overlay
        if let toast = reviewToast {
            Text(toast)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(24)
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        } // ZStack
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let jobResult = apiService.fetchJob(id: currentJob.id)
            async let invoiceResult = apiService.fetchJobInvoice(jobId: currentJob.id)
            async let apptResult = apiService.fetchJobAppointments(jobId: currentJob.id)
            if let updated = try? await jobResult {
                currentJob = updated
            }
            invoice = try? await invoiceResult
            appointments = (try? await apptResult) ?? []
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePickerView(sourceType: .camera) { image in
                uploadPhoto(image)
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            ReviewRequestSheet(
                jobId: currentJob.id,
                customerName: updatedContactLead?.name ?? currentJob.customerName ?? "Customer",
                customerEmail: updatedContactLead?.email ?? currentJob.customerEmail,
                customerPhone: updatedContactLead?.phone ?? currentJob.customerPhone
            ) { toastMessage in
                withAnimation { reviewToast = toastMessage }
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation { reviewToast = nil }
                }
            }
        }
        .alert("Review Request", isPresented: Binding(
            get: { reviewAlertMessage != nil },
            set: { if !$0 { reviewAlertMessage = nil } }
        )) {
            Button("OK") { reviewAlertMessage = nil }
        } message: {
            Text(reviewAlertMessage ?? "")
        }
        .alert("Call Error", isPresented: Binding(
            get: { callManager.errorMessage != nil },
            set: { if !$0 { callManager.errorMessage = nil } }
        )) {
            Button("OK") { callManager.errorMessage = nil }
        } message: {
            Text(callManager.errorMessage ?? "")
        }
        .sheet(isPresented: $showingRecurringInstances) {
            if let series = recurringInstances {
                RecurringInstancesView(series: series)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingCreateInvoice) {
            CreateInvoiceView(job: currentJob) { newInvoice in
                invoice = newInvoice
            }
        }
        .sheet(isPresented: $showingAddAppointment) {
            AppointmentFormView(jobId: currentJob.id, existing: nil) { appt in
                appointments.append(appt)
            }
        }
        .sheet(item: $editingAppointment) { appt in
            AppointmentFormView(jobId: currentJob.id, existing: appt) { updated in
                if let idx = appointments.firstIndex(where: { $0.id == updated.id }) {
                    appointments[idx] = updated
                }
            }
        }
    }

    private func handleReviewButtonTap() {
        guard currentJob.leadId != nil else {
            reviewAlertMessage = "This job has no customer linked."
            return
        }
        guard AccountManager.shared.currentAccount?.hasReviewLink == true else {
            reviewAlertMessage = "Add your Google Review Link in account settings to use this feature."
            return
        }
        showingReviewSheet = true
    }

    private func loadRecurringInstances() async {
        guard recurringInstances == nil else { return }
        isLoadingInstances = true
        defer { isLoadingInstances = false }
        recurringInstances = try? await apiService.fetchRecurringInstances(jobId: currentJob.id)
    }

    private func callViaTwilio(_ phone: String) {
        CallManager.shared.dial(
            to: phone,
            displayName: currentJob.customerName ?? phone
        )
    }

    private var jobLead: Lead? {
        guard let leadId = currentJob.leadId else { return nil }
        return Lead(id: leadId,
                    name: currentJob.customerName ?? "Customer",
                    email: currentJob.customerEmail,
                    phone: currentJob.customerPhone,
                    address: nil, source: nil, status: nil, tags: nil,
                    notes: nil, createdAt: Date())
    }

    private func openConversation() {
        guard let lead = jobLead else { return }
        navigateToConversation = lead
        isNavigatingToConversation = true
    }

    private func openMaps() {
        let address = currentJob.formattedAddress
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?daddr=\(address)") {
            UIApplication.shared.open(url)
        }
    }

    private func sendOnMyWay() async {
        guard let leadId = currentJob.leadId else { return }
        isSendingOnMyWay = true
        defer { isSendingOnMyWay = false }
        let message = "Hi\(currentJob.customerName.map { ", \($0.components(separatedBy: " ").first ?? $0)" } ?? "")! I'm on my way to your appointment and will be there shortly."
        let phoneLineId = PhoneLineManager.shared.selectedLine?.id
        do {
            _ = try await apiService.sendLeadMessage(leadId: leadId, channel: "sms", body: message, phoneLineId: phoneLineId)
            onMyWaySent = true
        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }

    private func uploadPhoto(_ image: UIImage) {
        print("📸 Uploading photo for job \(currentJob.id)")
    }

    private func deleteAppointment(_ appt: Appointment) async {
        try? await apiService.deleteAppointment(jobId: currentJob.id, appointmentId: appt.id)
        appointments.removeAll { $0.id == appt.id }
    }

}

// MARK: - Appointments Section

struct AppointmentsSectionView: View {
    let jobId: Int
    @Binding var appointments: [Appointment]
    let onAdd: () -> Void
    let onEdit: (Appointment) -> Void
    let onDelete: (Appointment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Appointments").font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if appointments.isEmpty {
                Text("No appointments scheduled")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(appointments) { appt in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(appt.startAt.formatted(date: .abbreviated, time: .shortened),
                                  systemImage: "calendar")
                                .font(.subheadline)
                            Spacer()
                            Button { onEdit(appt) } label: {
                                Image(systemName: "pencil").foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            Button { onDelete(appt) } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        if let end = appt.endAt {
                            Text("Until \(end.formatted(date: .omitted, time: .shortened))")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        if let notes = appt.notes, !notes.isEmpty {
                            Text(notes).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    if appt.id != appointments.last?.id { Divider() }
                }
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().scaleEffect(0.9).padding(.trailing, 4)
                } else {
                    Image(systemName: icon)
                }
                Text(isLoading ? "Updating..." : label)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isLoading)
    }
}

// MARK: - Status Picker

struct StatusPickerView: View {
    let currentStatus: JobStatus
    let onSelect: (JobStatus) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(JobStatus.allCases, id: \.self) { status in
                Button(action: {
                    onSelect(status)
                    dismiss()
                }) {
                    HStack {
                        StatusBadge(status: status)
                        Spacer()
                        if status == currentStatus {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Change Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Recurring Instances

struct RecurringInstancesView: View {
    let series: RecurringInstancesResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(series.instances) { job in
                NavigationLink(destination: JobDetailView(job: job)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(job.scheduledDate.map {
                                $0.formatted(date: .abbreviated, time: .omitted)
                            } ?? "No date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            Spacer()
                            StatusBadge(status: job.status)
                        }
                        if let time = job.scheduledTime {
                            Text(time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.plain)
            .navigationTitle("\(series.recurrenceLabel) — \(series.totalInstances) Jobs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
