//
//  MessagesView.swift
//  Animal CRM
//
//  Jobs list view - all jobs organized by status
//

import SwiftUI

struct MessagesView: View {
    @StateObject private var apiService = APIService.shared
    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var selectedFilter: JobStatus? = nil
    @State private var searchText = ""
    @State private var showingCreateJob = false
    @State private var newJob: Job?
    @State private var navigateToNewJob = false

    var filteredJobs: [Job] {
        var result = jobs

        if let filter = selectedFilter {
            result = result.filter { $0.status == filter }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.customerName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return result.sorted {
            ($0.scheduledDate ?? .distantPast) > ($1.scheduledDate ?? .distantPast)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterPill(title: "All", isSelected: selectedFilter == nil) {
                            selectedFilter = nil
                        }

                        ForEach(JobStatus.allCases, id: \.self) { status in
                            FilterPill(
                                title: status.displayName,
                                count: jobs.filter { $0.status == status }.count,
                                isSelected: selectedFilter == status
                            ) {
                                selectedFilter = status
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGray6))

                // Jobs List
                if isLoading && jobs.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredJobs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "briefcase")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Jobs Found")
                            .font(.headline)
                        Text(searchText.isEmpty ? "Try adjusting your filters" : "No jobs match your search")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredJobs) { job in
                        NavigationLink(destination: JobDetailView(job: job)) {
                            JobListRow(job: job)
                        }
                    }
                    .listStyle(.plain)
                }

                // Hidden nav link for new job
                NavigationLink(
                    destination: Group {
                        if let job = newJob { JobDetailView(job: job) }
                    },
                    isActive: $navigateToNewJob
                ) { EmptyView() }
            }
            .navigationTitle("All Jobs")
            .searchable(text: $searchText, prompt: "Search jobs or customers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateJob = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await loadJobs() }
            .task { await loadJobs() }
            .sheet(isPresented: $showingCreateJob, onDismiss: { Task { await loadJobs() } }) {
                CreateJobView { created in
                    newJob = created
                    navigateToNewJob = true
                }
                .environmentObject(apiService)
            }
        }
    }

    private func loadJobs() async {
        isLoading = true
        do {
            jobs = try await apiService.fetchAllJobs()
        } catch {
            print("❌ Error loading jobs: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if let count = count {
                    Text("(\(count))")
                        .font(.caption)
                }
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 2)
        }
    }
}

// MARK: - Job List Row

struct JobListRow: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.title)
                    .font(.headline)
                Spacer()
                StatusBadge(status: job.status)
            }

            if let customer = job.customerName {
                Text(customer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                if let date = job.scheduledDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let time = job.scheduledTime {
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let amount = job.formattedAmount {
                    Text(amount)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MessagesView()
}
