//
//  HomeView.swift
//  Animal CRM
//
//  Dashboard for field service workers
//

import SwiftUI

struct HomeView: View {
    @StateObject private var apiService = APIService.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var todaysJobs: [Job] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddLead = false
    @State private var statusFilter: JobStatus? = nil
    @State private var showingMap = false

    private var filteredJobs: [Job] {
        let sorted = todaysJobs.sorted {
            ($0.scheduledTime ?? "") < ($1.scheduledTime ?? "")
        }
        guard let filter = statusFilter else { return sorted }
        return sorted.filter { $0.status == filter }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Clock Widget
                    TimeClockWidget()

                    // Quick Stats (tappable to filter)
                    QuickStatsView(jobs: todaysJobs, activeFilter: statusFilter) { tapped in
                        statusFilter = (statusFilter == tapped) ? nil : tapped
                    }

                    // Today's Jobs Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(statusFilter.map { "\($0.displayName) Jobs" } ?? "Today's Jobs")
                                .font(.headline)
                            Spacer()
                            if statusFilter != nil {
                                Button("Clear") { statusFilter = nil }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            } else {
                                Text("\(filteredJobs.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if filteredJobs.isEmpty {
                            EmptyJobsView()
                        } else {
                            ForEach(filteredJobs) { job in
                                NavigationLink(destination: JobDetailView(job: job)) {
                                    JobCard(job: job)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Error Message
                    if let error = errorMessage {
                        VStack(spacing: 8) {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                            Button("Retry") { Task { await loadData() } }
                                .font(.caption).bold()
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingMap = true } label: {
                        Image(systemName: "map.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddLead = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLead) {
                AddLeadView()
            }
            .sheet(isPresented: $showingMap) {
                JobMapView(jobs: todaysJobs)
            }
            .refreshable {
                await loadData()
            }
            .task(id: accountManager.currentAccount?.id) {
                guard accountManager.currentAccount != nil else { return }
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        async let jobs = apiService.fetchTodaysJobs()
        async let _ = ClockInManager.shared.checkStatus()
        do {
            todaysJobs = try await jobs
        } catch is CancellationError {
            // Task cancelled (view disappeared mid-load) — ignore
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession cancelled — ignore
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error loading dashboard: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Quick Stats

struct QuickStatsView: View {
    let jobs: [Job]
    let activeFilter: JobStatus?
    let onTap: (JobStatus) -> Void

    var body: some View {
        HStack(spacing: 12) {
            StatCard(title: "Scheduled",  count: jobs.filter { $0.status == .scheduled  }.count,
                     color: .blue,   isActive: activeFilter == .scheduled)  { onTap(.scheduled)  }
            StatCard(title: "In Progress", count: jobs.filter { $0.status == .inProgress }.count,
                     color: .orange, isActive: activeFilter == .inProgress) { onTap(.inProgress) }
            StatCard(title: "Completed",  count: jobs.filter { $0.status == .completed  }.count,
                     color: .green,  isActive: activeFilter == .completed)  { onTap(.completed)  }
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? .white : color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(isActive ? .white.opacity(0.85) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? color : Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Job Card

struct JobCard: View {
    let job: Job
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.headline)
                    if let number = job.number {
                        Text(number)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                StatusBadge(status: job.status)
            }
            
            if let customer = job.customerName {
                Label(customer, systemImage: "person")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !job.formattedAddress.isEmpty {
                Label(job.formattedAddress, systemImage: "mappin.circle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack {
                if let time = job.scheduledTime {
                    Label(time, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let amount = job.formattedAmount {
                    Text(amount)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct StatusBadge: View {
    let status: JobStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(6)
    }
    
    var statusColor: Color {
        switch status {
        case .draft: return .gray
        case .scheduled: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Empty State

struct EmptyJobsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Jobs Scheduled")
                .font(.headline)
            Text("You have no jobs scheduled for today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    HomeView()
}
