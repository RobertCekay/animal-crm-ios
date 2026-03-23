//
//  JobEstimateFormViewModel.swift
//  Animal CRM
//
//  Shared view model for Create Estimate and Create Job forms.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class JobEstimateFormViewModel: ObservableObject {

    // MARK: - Section 1: Customer & Property
    @Published var selectedLead: Lead? = nil
    @Published var propertySelection: PropertySelection = .none
    @Published var leads: [Lead] = []
    @Published var properties: [Property] = []
    @Published var propertiesLoading = false

    // MARK: - Section 2: Appointment
    @Published var appointmentEnabled = false
    @Published var scheduledDate = Date()
    @Published var scheduledTime = Date()
    @Published var scheduledEndTime = Date()

    // MARK: - Recurring (Job only)
    @Published var isRecurring = false
    @Published var recurrenceFrequency: RecurrenceFrequency = .weekly
    @Published var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    // MARK: - Section 3: Notes
    @Published var notes = ""

    // MARK: - Section 4: Line Items
    @Published var lineItems: [LineItemDraft] = []
    @Published var products: [Product] = []

    var grandTotal: Double {
        lineItems.reduce(0) { $0 + $1.computedTotal }
    }

    // MARK: - Section 5: Settings (Job)
    @Published var sendInvoiceOnCreate = false
    @Published var sendAppointmentOnCreate = false
    @Published var sendAppointmentReminder = false
    @Published var appointmentReminderDays = 1
    @Published var depositAmount: String = ""

    // MARK: - Section 5: Settings (Estimate)
    @Published var sendEstimateOnCreate = false

    // MARK: - UI State
    @Published var settingsExpanded = false
    @Published var isSubmitting = false
    @Published var validationError: String?

    private let api = APIService.shared

    private let dateFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Load

    func loadInitialData() async {
        async let leadsResult: [Lead] = (try? await api.fetchLeads()) ?? []
        async let productsResult: [Product] = (try? await api.fetchProducts()) ?? []
        leads = await leadsResult
        products = await productsResult
    }

    func loadProperties(for leadId: Int) async {
        propertiesLoading = true
        propertySelection = .none
        defer { propertiesLoading = false }
        let loaded = (try? await api.fetchProperties(leadId: leadId)) ?? []
        properties = loaded
        // Auto-select primary property
        if let primary = loaded.first(where: { $0.primary }) {
            propertySelection = .existing(primary)
        }
    }

    // MARK: - Validation

    func validate(isJob: Bool) -> Bool {
        guard selectedLead != nil else {
            validationError = "Please select a customer."
            return false
        }
        if isJob && isRecurring && !appointmentEnabled {
            validationError = "Recurring jobs require a scheduled appointment."
            return false
        }
        return true
    }

    // MARK: - Request Builders

    func buildEstimateRequest() -> CreateEstimateRequest {
        let reqItems = validLineItems()
        return CreateEstimateRequest(
            leadId: selectedLead!.id,
            propertyId: resolvedPropertyId(),
            notes: notes.isEmpty ? nil : notes,
            scheduledDate: appointmentEnabled ? dateFmt.string(from: scheduledDate) : nil,
            scheduledTime: appointmentEnabled ? timeFmt.string(from: scheduledTime) : nil,
            scheduledEndTime: appointmentEnabled ? timeFmt.string(from: scheduledEndTime) : nil,
            sendEstimateOnCreate: sendEstimateOnCreate ? true : nil,
            lineItems: reqItems.isEmpty ? nil : reqItems
        )
    }

    func buildJobRequest() -> CreateJobRequest {
        let reqItems = validLineItems()
        let deposit = depositAmount.isEmpty ? nil : Double(depositAmount)
        return CreateJobRequest(
            leadId: selectedLead!.id,
            propertyId: resolvedPropertyId(),
            notes: notes.isEmpty ? nil : notes,
            address: resolvedFreeAddress(),
            scheduledDate: appointmentEnabled ? dateFmt.string(from: scheduledDate) : nil,
            scheduledTime: appointmentEnabled ? timeFmt.string(from: scheduledTime) : nil,
            scheduledEndTime: appointmentEnabled ? timeFmt.string(from: scheduledEndTime) : nil,
            sendInvoiceOnJobCreate: sendInvoiceOnCreate ? true : nil,
            sendAppointmentOnJobCreate: (appointmentEnabled && sendAppointmentOnCreate) ? true : nil,
            sendAppointmentReminder: (appointmentEnabled && sendAppointmentReminder) ? true : nil,
            appointmentReminderDays: (appointmentEnabled && sendAppointmentReminder) ? appointmentReminderDays : nil,
            depositAmount: deposit,
            lineItems: reqItems.isEmpty ? nil : reqItems,
            jobType: isRecurring ? "recurring" : "one_time",
            recurrenceFrequency: isRecurring ? recurrenceFrequency.rawValue : nil,
            recurrenceEndDate: isRecurring ? dateFmt.string(from: recurrenceEndDate) : nil
        )
    }

    // MARK: - Helpers

    private func validLineItems() -> [LineItemRequest] {
        lineItems
            .filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.toRequest() }
    }

    private func resolvedPropertyId() -> Int? {
        if case .existing(let p) = propertySelection { return p.id }
        return nil
    }

    private func resolvedFreeAddress() -> String? {
        if case .newAddress(_, let addr, let city, let state, let zip) = propertySelection {
            let parts = [addr, city, state, zip].filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
        return nil
    }
}
