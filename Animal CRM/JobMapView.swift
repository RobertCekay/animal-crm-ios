//
//  JobMapView.swift
//  Animal CRM
//
//  Map showing today's jobs as color-coded pins.
//

import SwiftUI
import MapKit

struct JobMapView: View {
    let jobs: [Job]
    @Environment(\.dismiss) private var dismiss

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
    )
    @State private var annotations: [JobAnnotation] = []
    @State private var selectedJob: Job?

    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: annotations) { ann in
                    MapAnnotation(coordinate: ann.coordinate) {
                        VStack(spacing: 0) {
                            Button {
                                selectedJob = ann.job
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(ann.color)
                                        .frame(width: 36, height: 36)
                                        .shadow(radius: 3)
                                    Image(systemName: "briefcase.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                            }
                            Triangle()
                                .fill(ann.color)
                                .frame(width: 10, height: 6)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                if annotations.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView("Geocoding addresses…")
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(12)
                }
            }
            .navigationTitle("Jobs Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedJob) { job in
                NavigationView {
                    JobDetailView(job: job)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Close") { selectedJob = nil }
                            }
                        }
                }
            }
            .task { await geocodeJobs() }
        }
    }

    @MainActor
    private func geocodeJobs() async {
        var anns: [JobAnnotation] = []
        await withTaskGroup(of: JobAnnotation?.self) { group in
            for job in jobs {
                let addr = job.formattedAddress
                guard !addr.isEmpty else { continue }
                group.addTask {
                    let geocoder = CLGeocoder()
                    let placemarks = try? await geocoder.geocodeAddressString(addr)
                    guard let loc = placemarks?.first?.location?.coordinate else { return nil }
                    return JobAnnotation(job: job, coordinate: loc)
                }
            }
            for await result in group {
                if let ann = result { anns.append(ann) }
            }
        }
        annotations = anns
        if let first = anns.first {
            region = MKCoordinateRegion(center: first.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3))
        }
    }
}

// MARK: - Annotation Model

private struct JobAnnotation: Identifiable {
    let id = UUID()
    let job: Job
    let coordinate: CLLocationCoordinate2D

    var color: Color {
        switch job.status {
        case .completed:  return .green
        case .inProgress: return .orange
        case .scheduled:  return .blue
        default:          return .gray
        }
    }
}

// MARK: - Pin Triangle

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}
