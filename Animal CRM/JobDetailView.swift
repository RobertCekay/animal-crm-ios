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
    @State private var showingStatusPicker = false
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var invoice: Invoice?
    @State private var showingInvoice = false
    @State private var smsConversation: SmsConversation?
    @State private var showingSMS = false
    @State private var isLoadingSMS = false
    @Environment(\.dismiss) private var dismiss

    init(job: Job) {
        self.job = job
        _currentJob = State(initialValue: job)
    }

    var body: some View {
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

                // Customer Info
                if currentJob.customerName != nil || currentJob.customerPhone != nil || currentJob.customerEmail != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Customer")
                            .font(.headline)

                        if let name = currentJob.customerName {
                            Label(name, systemImage: "person")
                        }

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

                                Button {
                                    textViaTwilio(phone)
                                } label: {
                                    HStack(spacing: 6) {
                                        if isLoadingSMS {
                                            ProgressView().scaleEffect(0.8).tint(.white)
                                        } else {
                                            Image(systemName: "message.fill")
                                        }
                                        Text("Text")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                }
                                .disabled(isLoadingSMS)

                                NavigationLink(destination: smsConversation.map {
                                    SMSThreadView(conversation: $0).environmentObject(apiService)
                                }, isActive: $showingSMS) {
                                    EmptyView()
                                }
                            }

                            if let email = currentJob.customerEmail {
                                Button(action: { emailCustomer(email) }) {
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

                // Location
                if currentJob.propertyId != nil || !currentJob.formattedAddress.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
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
                                } else if currentJob.propertyId != nil {
                                    Label("Address on file", systemImage: "mappin.circle.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if !currentJob.formattedAddress.isEmpty {
                                Button(action: { openMaps() }) {
                                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                }

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

                // Status Actions
                VStack(spacing: 12) {
                    // Primary status action
                    if currentJob.status == .scheduled {
                        ActionButton(
                            label: "Start Job",
                            icon: "play.circle.fill",
                            color: .orange,
                            isLoading: isUpdating
                        ) { updateStatus(.inProgress) }

                    } else if currentJob.status == .inProgress {
                        ActionButton(
                            label: "Complete Job",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            isLoading: isUpdating
                        ) { updateStatus(.completed) }
                    }

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

                    // Photo upload
                    Button(action: { showingPhotoPicker = true }) {
                        Label("Add Photos", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    // Generic status picker (for edge cases)
                    if currentJob.status != .completed && currentJob.status != .cancelled {
                        Button(action: { showingStatusPicker = true }) {
                            Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
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
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            invoice = try? await apiService.fetchJobInvoice(jobId: currentJob.id)
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePickerView(sourceType: .camera) { image in
                uploadPhoto(image)
            }
        }
        .sheet(isPresented: $showingStatusPicker) {
            StatusPickerView(currentStatus: currentJob.status) { newStatus in
                updateStatus(newStatus)
            }
        }
    }

    private func callViaTwilio(_ phone: String) {
        CallManager.shared.dial(
            to: phone,
            displayName: currentJob.customerName ?? phone
        )
    }

    private func textViaTwilio(_ phone: String) {
        isLoadingSMS = true
        Task {
            defer { isLoadingSMS = false }
            do {
                let conversation = try await apiService.findOrCreateSmsConversation(phone: phone)
                await MainActor.run {
                    smsConversation = conversation
                    showingSMS = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func emailCustomer(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }

    private func openMaps() {
        let address = currentJob.formattedAddress
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(address)") {
            UIApplication.shared.open(url)
        }
    }

    private func uploadPhoto(_ image: UIImage) {
        print("📸 Uploading photo for job \(currentJob.id)")
    }

    private func updateStatus(_ newStatus: JobStatus) {
        isUpdating = true
        errorMessage = nil
        Task {
            defer { isUpdating = false }
            do {
                let updated = try await apiService.updateJobStatus(id: currentJob.id, status: newStatus)
                await MainActor.run { currentJob = updated }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
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
