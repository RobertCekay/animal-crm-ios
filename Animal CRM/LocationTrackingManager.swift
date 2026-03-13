//
//  LocationTrackingManager.swift
//  Animal CRM
//
//  Owns the CLLocationManager and sends 5-minute location pings
//  to the server while a technician is clocked in.
//

import CoreLocation
import Foundation
import Combine

final class LocationTrackingManager: NSObject, CLLocationManagerDelegate, ObservableObject {

    static let shared = LocationTrackingManager()

    // MARK: - Published state

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private var pingTimer: Timer?
    private var activeEntryId: Int?

    /// Pings that failed to send (offline) — retried on next successful ping
    private var pendingPings: [LocationPingRequest] = []

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public interface

    func requestPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            // Escalate to Always
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func startTracking(entryId: Int) {
        activeEntryId = entryId
        locationManager.startUpdatingLocation()
        schedulePingTimer()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        pingTimer?.invalidate()
        pingTimer = nil
        activeEntryId = nil
        // Keep lastLocation so clockOut can use it
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        // If we're actively tracking and permission was just granted, ensure updates are running
        if activeEntryId != nil,
           manager.authorizationStatus == .authorizedAlways ||
           manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
    }

    // MARK: - Ping timer

    private func schedulePingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        guard let entryId = activeEntryId,
              let loc = lastLocation else { return }

        let ping = LocationPingRequest(
            latitude:   loc.coordinate.latitude,
            longitude:  loc.coordinate.longitude,
            accuracy:   loc.horizontalAccuracy > 0 ? loc.horizontalAccuracy : nil,
            speed:      loc.speed > 0 ? loc.speed : nil,
            recordedAt: loc.timestamp
        )

        Task {
            do {
                // Flush any queued offline pings first
                await flushPendingPings(entryId: entryId)
                _ = try await APIService.shared.sendLocationPing(entryId: entryId, ping: ping)
            } catch {
                // Queue for retry
                await MainActor.run { self.pendingPings.append(ping) }
                print("📍 Ping queued (offline): \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func flushPendingPings(entryId: Int) async {
        guard !pendingPings.isEmpty else { return }
        var remaining: [LocationPingRequest] = []
        for ping in pendingPings {
            do {
                _ = try await APIService.shared.sendLocationPing(entryId: entryId, ping: ping)
            } catch {
                remaining.append(ping)
            }
        }
        pendingPings = remaining
    }
}
