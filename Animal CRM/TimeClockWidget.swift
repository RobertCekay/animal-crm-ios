//
//  TimeClockWidget.swift
//  Animal CRM
//
//  Dashboard clock-in/out card with live elapsed timer,
//  optional job picker, and clock-out confirmation sheet.
//

import CoreLocation
import SwiftUI
import Combine

struct TimeClockWidget: View {
    @ObservedObject private var clockIn = ClockInManager.shared
    @ObservedObject private var location = LocationTrackingManager.shared

    @State private var todaysJobs: [Job] = []
    @State private var selectedJobId: Int? = nil
    @State private var showingClockOut = false
    @State private var isClockingIn = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if clockIn.isClockedIn {
                ClockedInCard(
                    entry: clockIn.activeEntry!,
                    onClockOut: { showingClockOut = true }
                )
            } else {
                ClockedOutCard(
                    jobs: todaysJobs,
                    selectedJobId: $selectedJobId,
                    locationStatus: location.authorizationStatus,
                    isLoading: isClockingIn || clockIn.isLoading,
                    onClockIn: handleClockIn,
                    onOpenSettings: openSettings
                )
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
        .sheet(isPresented: $showingClockOut) {
            ClockOutSheet(entry: clockIn.activeEntry) { notes in
                await handleClockOut(notes: notes)
            }
        }
        .task { await loadJobs() }
        .onAppear { location.requestPermission() }
    }

    // MARK: - Actions

    private func handleClockIn() {
        guard !isClockingIn else { return }

        // If permission denied, show alert
        if location.authorizationStatus == .denied || location.authorizationStatus == .restricted {
            errorMessage = "Location access is required for clock-in. Please enable it in Settings → Privacy → Location Services."
            return
        }

        isClockingIn = true
        Task {
            defer { isClockingIn = false }
            do {
                try await clockIn.clockIn(jobId: selectedJobId, notes: nil)
            } catch ClockError.locationUnavailable {
                errorMessage = "Unable to get your location. Please enable location services."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleClockOut(notes: String?) async {
        do {
            try await clockIn.clockOut(notes: notes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func loadJobs() async {
        todaysJobs = (try? await APIService.shared.fetchTodaysJobs()) ?? []
    }
}

// MARK: - Clocked Out Card

private struct ClockedOutCard: View {
    let jobs: [Job]
    @Binding var selectedJobId: Int?
    let locationStatus: CLAuthorizationStatus
    let isLoading: Bool
    let onClockIn: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 10, height: 10)
                Text("Not Clocked In")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Job picker
            if !jobs.isEmpty {
                Picker("Select Job (optional)", selection: $selectedJobId) {
                    Text("No specific job").tag(Int?.none)
                    ForEach(jobs) { job in
                        Text(job.number ?? job.title).tag(Optional(job.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Location warning
            if locationStatus == .denied || locationStatus == .restricted {
                HStack(spacing: 6) {
                    Image(systemName: "location.slash.fill")
                        .foregroundColor(.orange)
                    Text("Location disabled — tracking won't work.")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Fix") { onOpenSettings() }
                        .font(.caption).bold()
                        .foregroundColor(.blue)
                }
            } else if locationStatus == .authorizedWhenInUse {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Background location not enabled — tracking pauses when app is closed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            Button(action: onClockIn) {
                Group {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.85)
                            Text("Clocking in...")
                        }
                    } else {
                        Label("Clock In", systemImage: "clock.badge.checkmark.fill")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.headline)
            }
            .disabled(isLoading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal)
    }
}

// MARK: - Clocked In Card

private struct ClockedInCard: View {
    let entry: TimeEntry
    let onClockOut: () -> Void

    @State private var elapsed: String = "--"
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                // Pulsing green dot
                PulsingDot()
                Text("CLOCKED IN")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(.green)
                Spacer()
                Text(entry.clockIn, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = entry.jobTitle {
                        Label(title, systemImage: "briefcase.fill")
                            .font(.subheadline).fontWeight(.medium)
                    } else {
                        Text("No job selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(elapsed)
                        .font(.title2).bold()
                        .foregroundColor(.primary)
                }
                Spacer()
            }

            Button(action: onClockOut) {
                Label("Clock Out", systemImage: "stop.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal)
        .onAppear { updateElapsed() }
        .onReceive(timer) { _ in updateElapsed() }
    }

    private func updateElapsed() {
        let interval = Date().timeIntervalSince(entry.clockIn)
        let hours = Int(interval) / 3600
        let mins  = (Int(interval) % 3600) / 60
        elapsed = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }
}

// MARK: - Clock Out Sheet

private struct ClockOutSheet: View {
    let entry: TimeEntry?
    let onConfirm: (String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    @State private var isSubmitting = false

    private var elapsed: String {
        guard let e = entry else { return "--" }
        let interval = Date().timeIntervalSince(e.clockIn)
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Duration so far")
                        Spacer()
                        Text(elapsed).fontWeight(.semibold)
                    }
                    if let title = entry?.jobTitle {
                        HStack {
                            Text("Job")
                            Spacer()
                            Text(title).foregroundColor(.secondary)
                        }
                    }
                }
                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                Section {
                    Button {
                        isSubmitting = true
                        Task {
                            await onConfirm(notes.isEmpty ? nil : notes)
                            isSubmitting = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView().scaleEffect(0.85).padding(.trailing, 4) }
                            Text(isSubmitting ? "Clocking out..." : "Confirm Clock Out")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("Clock Out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
            }
        }
    }
}

// MARK: - Pulsing Dot

private struct PulsingDot: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 18, height: 18)
                .scaleEffect(pulse ? 1.5 : 1)
                .opacity(pulse ? 0 : 1)
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

#Preview {
    TimeClockWidget()
}
