//
//  ContactsView.swift
//  Animal CRM
//
//  Contacts (Leads) tab — paginated list with search, create, edit, delete
//

import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var contacts: [Lead] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var total = 0
    @Published var toastMessage: String?

    private var currentPage = 1
    private var totalPages = 1
    private var searchDebounce: Task<Void, Never>?

    var hasMore: Bool { currentPage < totalPages }

    func load(query: String? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        currentPage = 1
        do {
            let response = try await APIService.shared.fetchLeads(query: query)
            contacts = response.leads
            total = response.total ?? response.leads.count
            totalPages = response.totalPages ?? 1
        } catch is CancellationError {
            // Ignore cancellation
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore(query: String? = nil) async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1
        do {
            let response = try await APIService.shared.fetchLeads(query: query, page: nextPage)
            contacts.append(contentsOf: response.leads)
            currentPage = nextPage
            total = response.total ?? contacts.count
            totalPages = response.totalPages ?? 1
        } catch is CancellationError {
            // Ignore cancellation
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMore = false
    }

    func delete(lead: Lead) async {
        do {
            try await APIService.shared.deleteLead(id: lead.id)
            contacts.removeAll { $0.id == lead.id }
            total = max(0, total - 1)
            showToast("Contact deleted")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyCreated(_ lead: Lead) {
        contacts.insert(lead, at: 0)
        total += 1
        showToast("Contact created")
    }

    func applyUpdated(_ lead: Lead) {
        if let idx = contacts.firstIndex(where: { $0.id == lead.id }) {
            contacts[idx] = lead
        }
        showToast("Contact updated")
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            toastMessage = nil
        }
    }
}

// MARK: - Avatar Color

private func avatarBackground(for id: Int) -> Color {
    hslColor(hue: Double(id % 360), saturation: 0.55, lightness: 0.88)
}

private func avatarForeground(for id: Int) -> Color {
    hslColor(hue: Double(id % 360), saturation: 0.45, lightness: 0.35)
}

private func hslColor(hue: Double, saturation: Double, lightness: Double) -> Color {
    let h = hue / 360.0
    let s = saturation
    let l = lightness
    let c = (1 - abs(2 * l - 1)) * s
    let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
    let m = l - c / 2
    var r, g, b: Double
    switch h * 6 {
    case 0..<1: (r, g, b) = (c, x, 0)
    case 1..<2: (r, g, b) = (x, c, 0)
    case 2..<3: (r, g, b) = (0, c, x)
    case 3..<4: (r, g, b) = (0, x, c)
    case 4..<5: (r, g, b) = (x, 0, c)
    default:    (r, g, b) = (c, 0, x)
    }
    return Color(red: r + m, green: g + m, blue: b + m)
}

// MARK: - Avatar View

struct ContactAvatar: View {
    let lead: Lead
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarBackground(for: lead.id))
            Text(lead.initials)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(avatarForeground(for: lead.id))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Contacts List View

struct ContactsListView: View {
    @StateObject private var vm = ContactsViewModel()
    @EnvironmentObject private var api: APIService
    @State private var searchText = ""
    @State private var showingCreate = false
    @State private var editingLead: Lead?
    @State private var deleteTarget: Lead?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Group {
                    if vm.isLoading && vm.contacts.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.contacts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(searchText.isEmpty ? "No contacts yet" : "No matches")
                                .font(.headline)
                            if searchText.isEmpty {
                                Text("Tap + to add your first contact")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(vm.contacts) { lead in
                                NavigationLink(destination: ContactDetailView(lead: lead, onUpdated: vm.applyUpdated, onDeleted: { _ in
                                    vm.contacts.removeAll { $0.id == lead.id }
                                    vm.total = max(0, vm.total - 1)
                                })) {
                                    ContactRowView(lead: lead)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteTarget = lead
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editingLead = lead
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .onAppear {
                                    if lead.id == vm.contacts.last?.id {
                                        Task { await vm.loadMore(query: searchText.isEmpty ? nil : searchText) }
                                    }
                                }
                            }
                            if vm.isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await vm.load(query: searchText.isEmpty ? nil : searchText)
                        }
                    }
                }

                // Toast
                if let toast = vm.toastMessage {
                    Text(toast)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(20)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: toast)
                }
            }
            .navigationTitle(vm.total > 0 ? "Contacts (\(vm.total))" : "Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
            .onChange(of: searchText) { query in
                Task { await vm.load(query: query.isEmpty ? nil : query) }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateEditContactView { lead in
                    vm.applyCreated(lead)
                }
                .environmentObject(api)
            }
            .sheet(item: $editingLead) { lead in
                CreateEditContactView(existing: lead) { updated in
                    vm.applyUpdated(updated)
                }
                .environmentObject(api)
            }
            .alert("Delete Contact?", isPresented: $showDeleteConfirm, presenting: deleteTarget) { lead in
                Button("Delete", role: .destructive) { Task { await vm.delete(lead: lead) } }
                Button("Cancel", role: .cancel) {}
            } message: { lead in
                Text("\"\(lead.name)\" will be permanently deleted.")
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil), actions: {
                Button("OK") { vm.errorMessage = nil }
            }, message: { Text(vm.errorMessage ?? "") })
        }
        .task { await vm.load() }
    }
}

// MARK: - Contact Row

struct ContactRowView: View {
    let lead: Lead

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatar(lead: lead)

            VStack(alignment: .leading, spacing: 3) {
                Text(lead.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    if let email = lead.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if let phone = lead.formattedPhone ?? lead.phone, !phone.isEmpty {
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Contact Detail View

struct ContactDetailView: View {
    let lead: Lead
    let onUpdated: (Lead) -> Void
    let onDeleted: (Lead) -> Void

    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss
    @State private var currentLead: Lead
    @State private var showingEdit = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    init(lead: Lead, onUpdated: @escaping (Lead) -> Void, onDeleted: @escaping (Lead) -> Void) {
        self.lead = lead
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
        self._currentLead = State(initialValue: lead)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    ContactAvatar(lead: currentLead, size: 72)
                    Text(currentLead.name)
                        .font(.title2.bold())
                    if let biz = currentLead.businessName, !biz.isEmpty, biz != currentLead.name {
                        Text(biz)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Contact Info
                DetailCard(title: "Contact Info", systemImage: "person.fill") {
                    if let email = currentLead.email, !email.isEmpty {
                        Link(destination: URL(string: "mailto:\(email)")!) {
                            DetailRow(icon: "envelope", label: email)
                        }
                        .buttonStyle(.plain)
                    }
                    if let phone = currentLead.formattedPhone ?? currentLead.phone, !phone.isEmpty {
                        let raw = currentLead.phone ?? phone
                        Link(destination: URL(string: "tel:\(raw.filter { $0.isNumber })")!) {
                            DetailRow(icon: "phone", label: phone)
                        }
                        .buttonStyle(.plain)
                    }
                    if let address = currentLead.address, !address.isEmpty {
                        DetailRow(icon: "mappin.circle", label: address)
                    }
                    if currentLead.email == nil && currentLead.phone == nil && currentLead.address == nil {
                        Text("No contact details")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Pipeline
                if currentLead.pipeline != nil || currentLead.stage != nil {
                    DetailCard(title: "Pipeline", systemImage: "arrow.right.circle") {
                        if let pipeline = currentLead.pipeline {
                            DetailRow(icon: "chart.bar", label: pipeline)
                        }
                        if let stage = currentLead.stage {
                            DetailRow(icon: "flag", label: stage)
                        }
                    }
                }

                // Activity
                DetailCard(title: "Activity", systemImage: "chart.bar.fill") {
                    HStack(spacing: 0) {
                        ActivityStat(label: "Jobs", count: currentLead.jobsCount ?? 0)
                        Divider().frame(height: 40)
                        ActivityStat(label: "Estimates", count: currentLead.estimatesCount ?? 0)
                        Divider().frame(height: 40)
                        ActivityStat(label: "Invoices", count: currentLead.invoicesCount ?? 0)
                    }
                }

                // Properties
                if let props = currentLead.properties, !props.isEmpty {
                    DetailCard(title: "Service Locations", systemImage: "mappin.and.ellipse") {
                        ForEach(props) { prop in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(prop.name)
                                        .font(.subheadline.bold())
                                    if prop.primary {
                                        Text("Primary")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .cornerRadius(4)
                                    }
                                }
                                if !prop.fullAddress.isEmpty {
                                    Text(prop.fullAddress)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                            if prop.id != props.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                // Notes
                if let notes = currentLead.notes, !notes.isEmpty {
                    DetailCard(title: "Notes", systemImage: "note.text") {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Delete
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        if isDeleting { ProgressView().tint(.red) }
                        Text("Delete Contact")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .disabled(isDeleting)
            }
            .padding(.horizontal)
        }
        .navigationTitle(currentLead.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            CreateEditContactView(existing: currentLead) { updated in
                currentLead = updated
                onUpdated(updated)
            }
            .environmentObject(api)
        }
        .alert("Delete Contact?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await confirmDelete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(currentLead.name)\" will be permanently deleted.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
    }

    private func confirmDelete() async {
        isDeleting = true
        do {
            try await APIService.shared.deleteLead(id: currentLead.id)
            onDeleted(currentLead)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Detail Helpers

struct DetailCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            Text(label)
                .font(.subheadline)
        }
    }
}

struct ActivityStat: View {
    let label: String
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Create / Edit Contact Sheet

struct CreateEditContactView: View {
    let existing: Lead?
    let onSaved: (Lead) -> Void

    @EnvironmentObject var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var businessName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(existing: Lead? = nil, onSaved: @escaping (Lead) -> Void) {
        self.existing = existing
        self.onSaved = onSaved
    }

    var isEditing: Bool { existing != nil }

    var isValid: Bool {
        let hasName = !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                      !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        let hasBusiness = !businessName.trimmingCharacters(in: .whitespaces).isEmpty
        return hasName || hasBusiness
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                    TextField("Business Name (optional)", text: $businessName)
                        .textContentType(.organizationName)
                }

                Section("Contact") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section("Address") {
                    TextField("Street address (optional)", text: $address)
                        .textContentType(.fullStreetAddress)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Contact" : "New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await save() } } label: {
                        if isSubmitting { ProgressView() } else { Text("Save").bold() }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
        .onAppear { prefill() }
    }

    private func prefill() {
        guard let lead = existing else { return }
        firstName = lead.firstName ?? ""
        lastName = lead.lastName ?? ""
        businessName = lead.businessName ?? ""
        email = lead.email ?? ""
        phone = lead.formattedPhone ?? lead.phone ?? ""
        address = lead.address ?? ""
        notes = lead.notes ?? ""
        // If name but no split fields, try splitting
        if firstName.isEmpty && lastName.isEmpty && !lead.name.isEmpty {
            let parts = lead.name.split(separator: " ", maxSplits: 1)
            firstName = String(parts.first ?? "")
            lastName = parts.count > 1 ? String(parts[1]) : ""
        }
    }

    private func save() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let req = CreateLeadRequest(
            firstName: firstName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : lastName.trimmingCharacters(in: .whitespaces),
            businessName: businessName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : businessName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email.trimmingCharacters(in: .whitespaces),
            phone: phone.isEmpty ? nil : phone,
            address: address.isEmpty ? nil : address,
            notes: notes.isEmpty ? nil : notes
        )
        do {
            let saved: Lead
            if let existing {
                saved = try await api.updateLead(id: existing.id, body: req)
            } else {
                saved = try await api.createLeadStructured(req)
            }
            await MainActor.run {
                onSaved(saved)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContactsListView()
        .environmentObject(APIService.shared)
}
