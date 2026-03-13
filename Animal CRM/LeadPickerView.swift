//
//  LeadPickerView.swift
//  Animal CRM
//
//  Searchable lead picker sheet
//

import SwiftUI

struct LeadPickerView: View {
    @EnvironmentObject var api: APIService
    @Binding var selectedLead: Lead?
    @Environment(\.dismiss) private var dismiss

    @State private var leads: [Lead] = []
    @State private var search = ""
    @State private var isLoading = false
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
                    ProgressView("Loading leads...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text(search.isEmpty ? "No leads found" : "No matches")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filtered) { lead in
                        Button {
                            selectedLead = lead
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lead.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let phone = lead.phone {
                                        Text(phone)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedLead?.id == lead.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Lead")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search by name")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
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
        do {
            leads = try await api.fetchLeads()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
