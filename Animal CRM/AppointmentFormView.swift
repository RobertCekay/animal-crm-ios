//
//  AppointmentFormView.swift
//  Animal CRM
//
//  Create or edit a job appointment.
//

import SwiftUI

struct AppointmentFormView: View {
    let jobId: Int
    let existing: Appointment?
    let onSaved: (Appointment) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var startTime = Date()
    @State private var hasEndTime = false
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationView {
            Form {
                Section("Date & Time") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    Toggle("End Time", isOn: $hasEndTime)
                    if hasEndTime {
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Appointment" : "New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .onAppear { prefill() }
    }

    private func prefill() {
        guard let appt = existing else { return }
        date = appt.startAt
        startTime = appt.startAt
        if let end = appt.endAt {
            hasEndTime = true
            endTime = end
        }
        notes = appt.notes ?? ""
    }

    private var combinedStart: Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: startTime)
        return cal.date(from: DateComponents(
            year: d.year, month: d.month, day: d.day,
            hour: t.hour, minute: t.minute
        )) ?? startTime
    }

    private var combinedEnd: Date? {
        guard hasEndTime else { return nil }
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: endTime)
        return cal.date(from: DateComponents(
            year: d.year, month: d.month, day: d.day,
            hour: t.hour, minute: t.minute
        ))
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let appt: Appointment
            if let existing {
                appt = try await APIService.shared.updateAppointment(
                    jobId: jobId, appointmentId: existing.id,
                    startAt: combinedStart, endAt: combinedEnd,
                    notes: notes.isEmpty ? nil : notes
                )
            } else {
                appt = try await APIService.shared.createAppointment(
                    jobId: jobId, startAt: combinedStart, endAt: combinedEnd,
                    notes: notes.isEmpty ? nil : notes
                )
            }
            onSaved(appt)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
