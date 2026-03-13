//
//  EstimateListView.swift
//  Animal CRM
//
//  Estimates inbox — newest first, filter by status, tap to detail
//

import SwiftUI

struct EstimateListView: View {
    @EnvironmentObject var api: APIService
    @State private var estimates: [Estimate] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreate = false
    @State private var selectedFilter: String? = nil
    @State private var newEstimate: Estimate?
    @State private var navigateToNew = false

    private let statuses = ["open", "sent", "accepted", "declined"]

    var filtered: [Estimate] {
        guard let f = selectedFilter else { return estimates }
        return estimates.filter { $0.status == f }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterPill(title: "All", isSelected: selectedFilter == nil) {
                        selectedFilter = nil
                    }
                    ForEach(statuses, id: \.self) { s in
                        FilterPill(
                            title: s.capitalized,
                            count: estimates.filter { $0.status == s }.count,
                            isSelected: selectedFilter == s
                        ) { selectedFilter = s }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGray6))

            if isLoading && estimates.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No estimates")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if selectedFilter != nil {
                        Button("Clear filter") { selectedFilter = nil }
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { estimate in
                    NavigationLink(destination: EstimateDetailView(estimate: estimate)) {
                        EstimateRow(estimate: estimate)
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }

            // Hidden nav link for newly created estimate
            NavigationLink(
                destination: Group {
                    if let e = newEstimate { EstimateDetailView(estimate: e) }
                },
                isActive: $navigateToNew
            ) { EmptyView() }
        }
        .navigationTitle("Estimates")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingCreate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateEstimateView { created in
                estimates.insert(created, at: 0)
                newEstimate = created
                navigateToNew = true
            }
            .environmentObject(api)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            estimates = try await api.fetchEstimates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Row

struct EstimateRow: View {
    let estimate: Estimate

    var locationSubtitle: String {
        if let name = estimate.propertyName { return name }
        let addr = estimate.formattedPropertyAddress
        if !addr.isEmpty { return addr }
        return "No location"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(estimate.number)
                    .font(.headline)
                Spacer()
                Text(estimate.formattedTotal)
                    .font(.subheadline).fontWeight(.semibold)
                EstimateStatusBadge(status: estimate.status)
            }
            if let name = estimate.leadName {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text(locationSubtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct EstimateStatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "open":     return .gray
        case "sent":     return .blue
        case "accepted": return .green
        case "declined": return .red
        default:         return .gray
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }
}

#Preview {
    NavigationView {
        EstimateListView()
            .environmentObject(APIService.shared)
    }
}
