//
//  ClockInManager.swift
//  Animal CRM
//
//  Authoritative clock-in state. The server is the source of truth —
//  this manager syncs on every app launch and foreground transition.
//

import CoreLocation
import Foundation
import Combine

@MainActor
final class ClockInManager: ObservableObject {

    static let shared = ClockInManager()

    @Published var activeEntry: TimeEntry?
    @Published var isLoading = false
    @Published var error: String?

    var isClockedIn: Bool { activeEntry != nil }

    private init() {}

    // MARK: - Sync with server

    /// Call on every app launch and foreground transition.
    func checkStatus() async {
        do {
            activeEntry = try await APIService.shared.fetchActiveTimeEntry()
            if let entry = activeEntry {
                LocationTrackingManager.shared.startTracking(entryId: entry.id)
            }
        } catch {
            // fetchActiveTimeEntry returns nil on 404 — real errors reach here
            self.error = error.localizedDescription
        }
    }

    // MARK: - Clock In

    func clockIn(jobId: Int?, notes: String?) async throws {
        let location = currentLocation()
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let lat = location?.coordinate.latitude ?? 0
            let lon = location?.coordinate.longitude ?? 0
            let acc = location?.horizontalAccuracy ?? 0
            
            let entry = try await APIService.shared.clockIn(
                jobId: jobId,
                notes: notes,
                latitude: lat,
                longitude: lon,
                accuracy: acc
            )
            activeEntry = entry
            LocationTrackingManager.shared.startTracking(entryId: entry.id)
        } catch let apiError as APIError {
            // If already clocked in on another device, sync server state
            if case .serverError(let msg) = apiError, msg.contains("already") {
                await checkStatus()
            } else {
                throw apiError
            }
        }
    }

    // MARK: - Clock Out

    func clockOut(notes: String?) async throws {
        guard let entry = activeEntry else { return }
        let location = currentLocation()
        isLoading = true
        error = nil
        defer { isLoading = false }

        let lat = location?.coordinate.latitude ?? 0
        let lon = location?.coordinate.longitude ?? 0
        let acc = location?.horizontalAccuracy ?? 0
        
        let closed = try await APIService.shared.clockOut(
            timeEntryId: entry.id,
            latitude: lat,
            longitude: lon,
            accuracy: acc,
            notes: notes
        )
        LocationTrackingManager.shared.stopTracking()
        activeEntry = nil
        _ = closed   // returned entry available if caller needs duration
    }

    // MARK: - Helpers

    private func currentLocation() -> CLLocation? {
        LocationTrackingManager.shared.lastLocation
            ?? CLLocationManager().location
    }
}
