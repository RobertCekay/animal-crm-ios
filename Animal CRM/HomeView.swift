//
//  HomeView.swift
//  Animal CRM
//
//  Dashboard for field service workers
//

import SwiftUI

struct HomeView: View {
    @StateObject private var apiService = APIService.shared
    @State private var todaysJobs: [Job] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddLead = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Clock Widget
                    TimeClockWidget()

                    // Quick Stats
                    QuickStatsView(jobs: todaysJobs)
                    
                    // Today's Jobs Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Today's Jobs")
                                .font(.headline)
                            Spacer()
                            Text("\(todaysJobs.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if todaysJobs.isEmpty {
                            EmptyJobsView()
                        } else {
                            ForEach(todaysJobs) { job in
                                NavigationLink(destination: JobDetailView(job: job)) {
                                    JobCard(job: job)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddLead = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLead) {
                AddLeadView()
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            todaysJobs = try await apiService.fetchTodaysJobs()
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
    
    var scheduledCount: Int {
        jobs.filter { $0.status == .scheduled }.count
    }
    
    var inProgressCount: Int {
        jobs.filter { $0.status == .inProgress }.count
    }
    
    var completedCount: Int {
        jobs.filter { $0.status == .completed }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(title: "Scheduled", count: scheduledCount, color: .blue)
            StatCard(title: "In Progress", count: inProgressCount, color: .orange)
            StatCard(title: "Completed", count: completedCount, color: .green)
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Job Card

struct JobCard: View {
    let job: Job
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(job.title)
                    .font(.headline)
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
