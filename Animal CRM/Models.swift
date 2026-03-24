//
//  Models.swift
//  Animal CRM
//
//  Data models for the field service CRM
//

import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
    let role: String?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email, role
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

// MARK: - Job

struct Job: Codable, Identifiable {
    let id: Int
    let title: String
    let status: JobStatus
    let scheduledDate: Date?
    let scheduledTime: String?
    let address: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let leadId: Int?
    let propertyId: Int?
    let propertyName: String?
    let customerName: String?
    let customerPhone: String?
    let customerEmail: String?
    let notes: String?
    let number: String?
    let scheduledEndTime: String?
    let invoiceId: Int?
    let totalAmount: Double?
    let isPaid: Bool
    let lineItems: [LineItem]
    let createdAt: Date
    let updatedAt: Date
    let isRecurring: Bool
    let isChildInstance: Bool
    let recurrenceFrequency: String?
    let recurrenceLabel: String?
    let recurrenceEndDate: String?
    let parentJobId: Int?
    let recurringInstanceCount: Int?

    /// Resolved address: server merges property.address ?? job.address
    var formattedAddress: String {
        var parts: [String] = []
        if let a = address { parts.append(a) }
        if let c = city { parts.append(c) }
        if let s = state { parts.append(s) }
        if let z = zipCode { parts.append(z) }
        return parts.joined(separator: ", ")
    }

    var formattedAmount: String? {
        guard let amount = totalAmount else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: amount))
    }

    enum CodingKeys: String, CodingKey {
        case id, title, status, address, city, state, notes, number
        case scheduledDate = "scheduled_date"
        case scheduledTime = "scheduled_time"
        case scheduledEndTime = "scheduled_end_time"
        case zipCode = "zip_code"
        case leadId = "lead_id"
        case propertyId = "property_id"
        case propertyName = "property_name"
        case customerName = "customer_name"
        case customerPhone = "customer_phone"
        case customerEmail = "customer_email"
        case invoiceId = "invoice_id"
        case totalAmount = "total_amount"
        case isPaid = "is_paid"
        case lineItems = "line_items"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isRecurring = "is_recurring"
        case isChildInstance = "is_child_instance"
        case recurrenceFrequency = "recurrence_frequency"
        case recurrenceLabel = "recurrence_label"
        case recurrenceEndDate = "recurrence_end_date"
        case parentJobId = "parent_job_id"
        case recurringInstanceCount = "recurring_instance_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(Int.self,       forKey: .id)
        title                = try c.decode(String.self,    forKey: .title)
        status               = try c.decode(JobStatus.self, forKey: .status)
        number               = try c.decodeIfPresent(String.self, forKey: .number)
        scheduledDate        = try c.decodeIfPresent(Date.self,   forKey: .scheduledDate)
        scheduledTime        = try c.decodeIfPresent(String.self, forKey: .scheduledTime)
        scheduledEndTime     = try c.decodeIfPresent(String.self, forKey: .scheduledEndTime)
        address              = try c.decodeIfPresent(String.self, forKey: .address)
        city                 = try c.decodeIfPresent(String.self, forKey: .city)
        state                = try c.decodeIfPresent(String.self, forKey: .state)
        zipCode              = try c.decodeIfPresent(String.self, forKey: .zipCode)
        leadId               = try c.decodeIfPresent(Int.self,    forKey: .leadId)
        propertyId           = try c.decodeIfPresent(Int.self,    forKey: .propertyId)
        propertyName         = try c.decodeIfPresent(String.self, forKey: .propertyName)
        customerName         = try c.decodeIfPresent(String.self, forKey: .customerName)
        customerPhone        = try c.decodeIfPresent(String.self, forKey: .customerPhone)
        customerEmail        = try c.decodeIfPresent(String.self, forKey: .customerEmail)
        notes                = try c.decodeIfPresent(String.self, forKey: .notes)
        invoiceId            = try c.decodeIfPresent(Int.self,    forKey: .invoiceId)
        isPaid               = (try? c.decode(Bool.self, forKey: .isPaid)) ?? false
        lineItems            = (try? c.decode([LineItem].self, forKey: .lineItems)) ?? []
        createdAt            = try c.decode(Date.self, forKey: .createdAt)
        updatedAt            = try c.decode(Date.self, forKey: .updatedAt)
        isRecurring          = (try? c.decode(Bool.self, forKey: .isRecurring)) ?? false
        isChildInstance      = (try? c.decode(Bool.self, forKey: .isChildInstance)) ?? false
        recurrenceFrequency  = try c.decodeIfPresent(String.self, forKey: .recurrenceFrequency)
        recurrenceLabel      = try c.decodeIfPresent(String.self, forKey: .recurrenceLabel)
        recurrenceEndDate    = try c.decodeIfPresent(String.self, forKey: .recurrenceEndDate)
        parentJobId          = try c.decodeIfPresent(Int.self,    forKey: .parentJobId)
        recurringInstanceCount = try c.decodeIfPresent(Int.self,  forKey: .recurringInstanceCount)
        if let v = try? c.decode(Double.self, forKey: .totalAmount) {
            totalAmount = v
        } else if let s = try? c.decode(String.self, forKey: .totalAmount), let v = Double(s) {
            totalAmount = v
        } else {
            totalAmount = nil
        }
    }
}

enum JobStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case scheduled = "scheduled"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .scheduled: return "blue"
        case .inProgress: return "orange"
        case .completed: return "green"
        case .cancelled: return "red"
        }
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case weekly    = "weekly"
    case biweekly  = "biweekly"
    case monthly   = "monthly"
    case quarterly = "quarterly"

    var displayName: String {
        switch self {
        case .weekly:    return "Weekly"
        case .biweekly:  return "Every 2 Weeks"
        case .monthly:   return "Monthly"
        case .quarterly: return "Quarterly"
        }
    }
}

// MARK: - Lead (Contact)

struct Lead: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let firstName: String?
    let lastName: String?
    let businessName: String?
    let email: String?
    let phone: String?
    let formattedPhone: String?
    let address: String?
    let source: String?
    let sourceId: Int?
    let status: String?
    let stageId: Int?
    let stage: String?
    let pipelineId: Int?
    let pipeline: String?
    let companyId: Int?
    let company: String?
    let tags: [String]?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date?
    let jobsCount: Int?
    let estimatesCount: Int?
    let invoicesCount: Int?
    let properties: [Property]?

    init(id: Int, name: String, email: String?, phone: String?,
         address: String?, source: String?, status: String?,
         tags: [String]?, notes: String?, createdAt: Date,
         firstName: String? = nil, lastName: String? = nil,
         businessName: String? = nil, formattedPhone: String? = nil,
         sourceId: Int? = nil, stageId: Int? = nil, stage: String? = nil,
         pipelineId: Int? = nil, pipeline: String? = nil,
         companyId: Int? = nil, company: String? = nil,
         updatedAt: Date? = nil, jobsCount: Int? = nil,
         estimatesCount: Int? = nil, invoicesCount: Int? = nil,
         properties: [Property]? = nil) {
        self.id = id; self.name = name; self.email = email; self.phone = phone
        self.address = address; self.source = source; self.status = status
        self.tags = tags; self.notes = notes; self.createdAt = createdAt
        self.firstName = firstName; self.lastName = lastName
        self.businessName = businessName; self.formattedPhone = formattedPhone
        self.sourceId = sourceId; self.stageId = stageId; self.stage = stage
        self.pipelineId = pipelineId; self.pipeline = pipeline
        self.companyId = companyId; self.company = company
        self.updatedAt = updatedAt; self.jobsCount = jobsCount
        self.estimatesCount = estimatesCount; self.invoicesCount = invoicesCount
        self.properties = properties
    }

    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, address, source, status, tags, notes, stage, pipeline, company, properties
        case firstName = "first_name"
        case lastName = "last_name"
        case businessName = "business_name"
        case formattedPhone = "formatted_phone"
        case sourceId = "source_id"
        case stageId = "stage_id"
        case pipelineId = "pipeline_id"
        case companyId = "company_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case jobsCount = "jobs_count"
        case estimatesCount = "estimates_count"
        case invoicesCount = "invoices_count"
    }
}

// MARK: - Time Entry

struct TimeEntry: Codable, Identifiable {
    let id: Int
    let jobId: Int?
    let jobTitle: String?
    let userId: Int
    let clockIn: Date
    let clockOut: Date?
    let durationMinutes: Int?
    let durationFormatted: String
    let notes: String?
    let clockInLatitude: Double?
    let clockInLongitude: Double?
    let clockOutLatitude: Double?
    let clockOutLongitude: Double?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, notes
        case jobId            = "job_id"
        case jobTitle         = "job_title"
        case userId           = "user_id"
        case clockIn          = "clock_in"
        case clockOut         = "clock_out"
        case durationMinutes  = "duration_minutes"
        case durationFormatted = "duration_formatted"
        case clockInLatitude  = "clock_in_latitude"
        case clockInLongitude = "clock_in_longitude"
        case clockOutLatitude  = "clock_out_latitude"
        case clockOutLongitude = "clock_out_longitude"
        case isActive         = "is_active"
    }
}

// MARK: - Clock Errors

enum ClockError: Error {
    case locationUnavailable
    case alreadyClockedIn
}

// MARK: - Location Ping

struct LocationPing: Codable, Identifiable {
    let id: Int
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let speed: Double?
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, accuracy, speed
        case recordedAt = "recorded_at"
    }
}

struct LocationPingRequest: Encodable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let speed: Double?
    let recordedAt: Date?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, accuracy, speed
        case recordedAt = "recorded_at"
    }
}

// MARK: - Estimate

struct Estimate: Codable, Identifiable {
    let id: Int
    let number: String
    let status: String          // "open" | "sent" | "accepted" | "declined"
    let leadId: Int
    let leadName: String?
    let notes: String?
    let totalAmount: Double
    let lineItems: [LineItem]
    let propertyId: Int?
    let propertyName: String?
    let propertyAddress: String?
    let propertyCity: String?
    let propertyState: String?
    let propertyZip: String?
    let sentToCustomerAt: Date?
    let acceptedByCustomerAt: Date?
    let declinedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var formattedTotal: String { String(format: "$%.2f", totalAmount) }

    // MARK: - Custom decode (totalAmount may arrive as string or number)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                    = try c.decode(Int.self,     forKey: .id)
        number                = try c.decode(String.self,  forKey: .number)
        status                = try c.decode(String.self,  forKey: .status)
        leadId                = try c.decode(Int.self,     forKey: .leadId)
        leadName              = try c.decodeIfPresent(String.self, forKey: .leadName)
        notes                 = try c.decodeIfPresent(String.self, forKey: .notes)
        totalAmount           = try Estimate.flexDouble(c, key: .totalAmount)
        lineItems             = try c.decode([LineItem].self, forKey: .lineItems)
        propertyId            = try c.decodeIfPresent(Int.self,    forKey: .propertyId)
        propertyName          = try c.decodeIfPresent(String.self, forKey: .propertyName)
        propertyAddress       = try c.decodeIfPresent(String.self, forKey: .propertyAddress)
        propertyCity          = try c.decodeIfPresent(String.self, forKey: .propertyCity)
        propertyState         = try c.decodeIfPresent(String.self, forKey: .propertyState)
        propertyZip           = try c.decodeIfPresent(String.self, forKey: .propertyZip)
        sentToCustomerAt      = try c.decodeIfPresent(Date.self,   forKey: .sentToCustomerAt)
        acceptedByCustomerAt  = try c.decodeIfPresent(Date.self,   forKey: .acceptedByCustomerAt)
        declinedAt            = try c.decodeIfPresent(Date.self,   forKey: .declinedAt)
        createdAt             = try c.decode(Date.self,   forKey: .createdAt)
        updatedAt             = try c.decode(Date.self,   forKey: .updatedAt)
    }

    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        let s = try c.decode(String.self, forKey: key)
        guard let v = Double(s) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: c,
                debugDescription: "Cannot convert \"\(s)\" to Double")
        }
        return v
    }

    var formattedPropertyAddress: String {
        let parts = [propertyAddress, propertyCity, propertyState, propertyZip]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id, number, status, notes
        case leadId = "lead_id"
        case leadName = "lead_name"
        case totalAmount = "total_amount"
        case lineItems = "line_items"
        case propertyId = "property_id"
        case propertyName = "property_name"
        case propertyAddress = "property_address"
        case propertyCity = "property_city"
        case propertyState = "property_state"
        case propertyZip = "property_zip"
        case sentToCustomerAt = "sent_to_customer_at"
        case acceptedByCustomerAt = "accepted_by_customer_at"
        case declinedAt = "declined_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct LineItem: Identifiable {
    let id: Int
    let description: String?
    let quantity: Int
    let unitPrice: Double
    let total: Double

    var formattedTotal: String { String(format: "$%.2f", total) }
}

extension LineItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, description, quantity, total
        case unitPrice = "unit_price"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(Int.self, forKey: .id)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        quantity    = try c.decode(Int.self, forKey: .quantity)
        unitPrice   = try Self.flexDouble(c, key: .unitPrice)
        total       = try Self.flexDouble(c, key: .total)
    }

    /// Decodes a Double that the server may send as either a number or a string.
    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        let s = try c.decode(String.self, forKey: key)
        guard let v = Double(s) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: c,
                debugDescription: "Cannot convert \"\(s)\" to Double")
        }
        return v
    }
}

// MARK: - Request Bodies

struct CreateJobRequest: Encodable {
    let leadId: Int
    let propertyId: Int?
    let notes: String?
    let address: String?
    let scheduledDate: String?
    let scheduledTime: String?
    let scheduledEndTime: String?
    let sendInvoiceOnJobCreate: Bool?
    let sendAppointmentOnJobCreate: Bool?
    let sendAppointmentReminder: Bool?
    let appointmentReminderDays: Int?
    let depositAmount: Double?
    let lineItems: [LineItemRequest]?
    let jobType: String?
    let recurrenceFrequency: String?
    let recurrenceEndDate: String?

    enum CodingKeys: String, CodingKey {
        case notes, address
        case leadId = "lead_id"
        case propertyId = "property_id"
        case scheduledDate = "scheduled_date"
        case scheduledTime = "scheduled_time"
        case scheduledEndTime = "scheduled_end_time"
        case sendInvoiceOnJobCreate = "send_invoice_on_job_create"
        case sendAppointmentOnJobCreate = "send_appointment_on_job_create"
        case sendAppointmentReminder = "send_appointment_reminder"
        case appointmentReminderDays = "appointment_reminder_days"
        case depositAmount = "deposit_amount"
        case lineItems = "line_items"
        case jobType = "job_type"
        case recurrenceFrequency = "recurrence_frequency"
        case recurrenceEndDate = "recurrence_end_date"
    }
}

struct CreateEstimateRequest: Encodable {
    let leadId: Int
    let propertyId: Int?
    let notes: String?
    let scheduledDate: String?
    let scheduledTime: String?
    let scheduledEndTime: String?
    let sendEstimateOnCreate: Bool?
    let lineItems: [LineItemRequest]?

    enum CodingKeys: String, CodingKey {
        case notes
        case leadId = "lead_id"
        case propertyId = "property_id"
        case scheduledDate = "scheduled_date"
        case scheduledTime = "scheduled_time"
        case scheduledEndTime = "scheduled_end_time"
        case sendEstimateOnCreate = "send_estimate_on_create"
        case lineItems = "line_items"
    }
}

struct UpdateEstimateRequest: Encodable {
    let notes: String?
    let propertyId: Int?
    let lineItems: [LineItemRequest]?

    enum CodingKeys: String, CodingKey {
        case notes
        case propertyId = "property_id"
        case lineItems = "line_items"
    }
}

struct LineItemRequest: Encodable {
    let productId: Int?
    let description: String
    let quantity: Int
    let unitPrice: Double

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let pid = productId { try c.encode(pid, forKey: .productId) }
        try c.encode(description, forKey: .description)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(unitPrice, forKey: .unitPrice)
    }

    enum CodingKeys: String, CodingKey {
        case description, quantity
        case productId = "product_id"
        case unitPrice = "unit_price"
    }
}

// MARK: - Local Mutable Draft (not Codable)

struct LineItemDraft: Identifiable {
    let id: UUID
    var productId: Int?
    var description: String
    var quantity: Int
    var unitPrice: Double

    init(id: UUID = UUID(), productId: Int? = nil, description: String = "", quantity: Int = 1, unitPrice: Double = 0) {
        self.id = id
        self.productId = productId
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
    }

    var computedTotal: Double { Double(quantity) * unitPrice }

    func toRequest() -> LineItemRequest {
        LineItemRequest(productId: productId, description: description, quantity: quantity, unitPrice: unitPrice)
    }
}

// MARK: - Product (catalog)

struct Product: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let unitPrice: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case unitPrice = "unit_price"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        if let v = try? c.decode(Double.self, forKey: .unitPrice) {
            unitPrice = v
        } else if let s = try? c.decode(String.self, forKey: .unitPrice), let v = Double(s) {
            unitPrice = v
        } else {
            unitPrice = nil
        }
    }
}

// MARK: - Invoice

struct Invoice: Codable, Identifiable {
    let id: Int
    let number: String
    let jobId: Int?
    let leadId: Int?
    let leadName: String?
    let totalAmount: Double
    let remainingAmount: Double?
    let status: String          // "draft" | "sent" | "paid" | "overdue"
    let isPaid: Bool
    let issuedOn: Date?
    let dueDate: Date?
    let paidAt: Date?
    let lineItems: [LineItem]
    let createdAt: Date

    var formattedTotal: String { Invoice.currency(totalAmount) }
    var formattedRemaining: String { Invoice.currency(remainingAmount ?? totalAmount) }

    static func currency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }

    enum CodingKeys: String, CodingKey {
        case id, number, status
        case jobId          = "job_id"
        case leadId         = "lead_id"
        case leadName       = "lead_name"
        case totalAmount    = "total_amount"
        case remainingAmount = "remaining_amount"
        case isPaid         = "is_paid"
        case issuedOn       = "issued_on"
        case dueDate        = "due_date"
        case paidAt         = "paid_at"
        case lineItems      = "line_items"
        case createdAt      = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(Int.self,    forKey: .id)
        number          = try c.decode(String.self, forKey: .number)
        status          = try c.decode(String.self, forKey: .status)
        jobId           = try c.decodeIfPresent(Int.self,    forKey: .jobId)
        leadId          = try c.decodeIfPresent(Int.self,    forKey: .leadId)
        leadName        = try c.decodeIfPresent(String.self, forKey: .leadName)
        totalAmount     = Invoice.flexDouble(c, key: .totalAmount) ?? 0
        remainingAmount = Invoice.flexDouble(c, key: .remainingAmount)
        isPaid          = (try? c.decode(Bool.self, forKey: .isPaid)) ?? false
        issuedOn        = try c.decodeIfPresent(Date.self,   forKey: .issuedOn)
        dueDate         = try c.decodeIfPresent(Date.self,   forKey: .dueDate)
        paidAt          = try c.decodeIfPresent(Date.self,   forKey: .paidAt)
        lineItems       = (try? c.decode([LineItem].self, forKey: .lineItems)) ?? []
        createdAt       = try c.decode(Date.self, forKey: .createdAt)
    }

    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v }
        return nil
    }
}

// MARK: - Property (service location)

struct Property: Codable, Identifiable, Equatable {
    let id: Int
    let leadId: Int
    let name: String
    let address: String?
    let addressLine2: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String?
    let notes: String?
    let primary: Bool
    let createdAt: Date

    var fullAddress: String {
        var parts: [String] = []
        if let a = address { parts.append(a) }
        if let a2 = addressLine2 { parts.append(a2) }
        if let c = city { parts.append(c) }
        if let s = state { parts.append(s) }
        if let z = zip { parts.append(z) }
        return parts.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, address, city, state, zip, country, notes, primary
        case leadId = "lead_id"
        case addressLine2 = "address_line_2"
        case createdAt = "created_at"
    }
}

struct CreatePropertyRequest: Encodable {
    let name: String
    let address: String?
    let addressLine2: String?
    let city: String?
    let state: String?
    let zip: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name, address, city, state, zip, notes
        case addressLine2 = "address_line_2"
    }
}

// MARK: - Lead Conversation

enum MessageType: String, Codable {
    case email, sms, call
}

enum MessageChannel: String, CaseIterable {
    case email = "email"
    case sms   = "sms"

    var label: String {
        switch self {
        case .email: return "Email"
        case .sms:   return "Text Message"
        }
    }
    var icon: String {
        switch self {
        case .email: return "envelope"
        case .sms:   return "message"
        }
    }
}

struct LeadMessage: Codable, Identifiable {
    var id: String {
        let ts = sentAt.map { "\($0.timeIntervalSince1970)" }
            ?? startedAt.map { "\($0.timeIntervalSince1970)" }
            ?? UUID().uuidString
        return "\(type.rawValue)-\(ts)"
    }
    let type: MessageType
    let direction: String       // "inbound" | "outbound"
    let body: String?
    let subject: String?
    let status: String?
    let duration: String?
    let number: String?
    let sentAt: Date?
    let startedAt: Date?
    let read: Bool?

    var isOutbound: Bool { direction == "outbound" }

    enum CodingKeys: String, CodingKey {
        case type, direction, body, subject, status, duration, number, read
        case sentAt     = "sent_at"
        case startedAt  = "started_at"
    }
}

struct LeadMessagesResponse: Codable {
    let messages: [LeadMessage]
    let canEmail: Bool
    let canSms: Bool
    let leadEmail: String?
    let leadPhone: String?

    enum CodingKeys: String, CodingKey {
        case messages
        case canEmail  = "can_email"
        case canSms    = "can_sms"
        case leadEmail = "lead_email"
        case leadPhone = "lead_phone"
    }
}

struct SendMessageResponse: Codable {
    let ok: Bool?
    let channel: String?
    let message: LeadMessage
}

// MARK: - Phone Lines

struct PhoneLine: Decodable, Identifiable {
    let id: Int
    let displayName: String
    let phoneNumber: String

    // Flexible decoder: tries display_name → name → friendly_name → falls back to phone_number
    private enum CodingKeys: String, CodingKey {
        case id
        case displayName  = "display_name"
        case name
        case friendlyName = "friendly_name"
        case phoneNumber  = "phone_number"
    }

    init(id: Int, displayName: String, phoneNumber: String) {
        self.id = id
        self.displayName = displayName
        self.phoneNumber = phoneNumber
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(Int.self, forKey: .id)
        phoneNumber = try c.decode(String.self, forKey: .phoneNumber)
        if let v = try? c.decode(String.self, forKey: .displayName), !v.isEmpty {
            displayName = v
        } else if let v = try? c.decode(String.self, forKey: .name), !v.isEmpty {
            displayName = v
        } else if let v = try? c.decode(String.self, forKey: .friendlyName), !v.isEmpty {
            displayName = v
        } else {
            displayName = phoneNumber
        }
    }
}

struct PhoneLinesResponse: Decodable {
    let phoneLines: [PhoneLine]

    // Handles both camelCase ("phoneLines") and snake_case ("phone_lines") wrapper keys
    private enum CodingKeys: String, CodingKey {
        case phoneLines       = "phoneLines"
        case phoneLinesSnake  = "phone_lines"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let lines = try? c.decode([PhoneLine].self, forKey: .phoneLines) {
            phoneLines = lines
        } else {
            phoneLines = try c.decode([PhoneLine].self, forKey: .phoneLinesSnake)
        }
    }
}

// MARK: - Accounts

struct Account: Codable, Identifiable {
    let id: Int
    let name: String
    let businessName: String?
    let isOwner: Bool
    let hasReviewLink: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case businessName  = "business_name"
        case isOwner       = "is_owner"
        case hasReviewLink = "has_review_link"
    }
}

struct AccountsResponse: Codable {
    let accounts: [Account]
}

// MARK: - Review Request

enum ReviewChannel: String, CaseIterable {
    case email, sms
}

struct ReviewRequestResponse: Decodable {
    let success: Bool
    let channel: String
    let reviewUrl: String?
    let sentTo: String?

    enum CodingKeys: String, CodingKey {
        case success, channel
        case reviewUrl = "review_url"
        case sentTo    = "sent_to"
    }
}

// MARK: - SMS

struct SmsConversation: Codable, Identifiable {
    let id: Int
    let contactNumber: String
    let leadId: Int?
    let leadName: String?
    let snippet: String?
    let unreadCount: Int
    let lastMessageAt: Date?
    let phoneLineId: Int?
    let createdAt: Date

    /// Lead name if available, otherwise falls back to the contact number.
    var displayName: String {
        if let name = leadName, !name.isEmpty { return name }
        return contactNumber
    }

    var initials: String { String(displayName.prefix(1)).uppercased() }

    enum CodingKeys: String, CodingKey {
        case id, snippet
        case contactNumber = "contact_number"
        case leadId = "lead_id"
        case leadName = "lead_name"
        case unreadCount = "unread_count"
        case lastMessageAt = "last_message_at"
        case phoneLineId = "phone_line_id"
        case createdAt = "created_at"
    }
}

struct SmsMessage: Codable, Identifiable {
    let id: Int
    let body: String
    let direction: String   // "inbound" or "outbound"
    let status: String?
    let fromNumber: String?
    let toNumber: String?
    let read: Bool
    let sentAt: Date?

    var isOutbound: Bool { direction == "outbound" }

    enum CodingKeys: String, CodingKey {
        case id, body, direction, status, read
        case fromNumber = "from_number"
        case toNumber = "to_number"
        case sentAt = "sent_at"
    }
}

// MARK: - Calls

struct CallToken: Codable {
    let token: String
    let identity: String
    let phoneLineId: Int
    let fromNumber: String

    enum CodingKeys: String, CodingKey {
        case token, identity
        case phoneLineId = "phone_line_id"
        case fromNumber = "from_number"
    }
}

struct CallRecord: Codable, Identifiable {
    let id: Int
    let direction: String   // "inbound" or "outbound"
    let status: String
    let fromNumber: String?
    let toNumber: String?
    let duration: Int?
    let durationDisplay: String?
    let leadId: Int?
    let leadName: String?
    let startedAt: Date?
    let endedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, direction, status, duration
        case fromNumber = "from_number"
        case toNumber = "to_number"
        case durationDisplay = "duration_display"
        case leadId = "lead_id"
        case leadName = "lead_name"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
    }
}

// MARK: - API Responses

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct JobsResponse: Codable {
    let jobs: [Job]
}

struct JobResponse: Codable {
    let job: Job
}

struct RecurringInstancesResponse: Codable {
    let parentJobId: Int
    let recurrenceFrequency: String
    let recurrenceLabel: String
    let recurrenceEndDate: String?
    let totalInstances: Int
    let instances: [Job]

    enum CodingKeys: String, CodingKey {
        case instances
        case parentJobId         = "parent_job_id"
        case recurrenceFrequency = "recurrence_frequency"
        case recurrenceLabel     = "recurrence_label"
        case recurrenceEndDate   = "recurrence_end_date"
        case totalInstances      = "total_instances"
    }
}

struct LeadsResponse: Codable {
    let leads: [Lead]
    let total: Int?
    let page: Int?
    let limit: Int?
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case leads, total, page, limit
        case totalPages = "total_pages"
    }
}

struct CreateLeadRequest: Encodable {
    let firstName: String?
    let lastName: String?
    let businessName: String?
    let email: String?
    let phone: String?
    let address: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case email, phone, address, notes
        case firstName = "first_name"
        case lastName = "last_name"
        case businessName = "business_name"
    }
}

struct DeleteResponse: Decodable {
    let success: Bool?
    let id: Int?
}

struct TimeEntriesResponse: Codable {
    let timeEntries: [TimeEntry]
    
    enum CodingKeys: String, CodingKey {
        case timeEntries = "time_entries"
    }
}

struct SmsConversationsResponse: Codable {
    let conversations: [SmsConversation]
}

struct SmsConversationResponse: Codable {
    let conversation: SmsConversation
}

struct SmsThreadResponse: Codable {
    let conversation: SmsConversation
    let messages: [SmsMessage]
}

struct SmsReplyResponse: Codable {
    let message: SmsMessage
}

struct CallsResponse: Codable {
    let calls: [CallRecord]
}

struct ProductsResponse: Codable {
    let products: [Product]
}

struct InvoiceResponse: Codable {
    let invoice: Invoice
}

struct EstimatesResponse: Codable {
    let estimates: [Estimate]
}

struct PropertiesResponse: Codable {
    let properties: [Property]
}

struct PropertyResponse: Codable {
    let property: Property
}

struct UploadResponse: Codable {
    let success: Bool
    let url: String
    let id: Int?
}

// MARK: - Unified Conversations

struct Conversation: Codable, Identifiable {
    let id: Int
    let platform: String          // "sms" or "email"
    let leadId: Int?
    let leadName: String?
    let contactNumber: String?    // SMS only
    let snippet: String?
    var unreadCount: Int
    let lastMessageAt: Date?

    var isSms:   Bool { platform == "sms" }
    var isEmail: Bool { platform == "email" }

    var displayName: String {
        if let n = leadName, !n.isEmpty { return n }
        return contactNumber ?? "Unknown"
    }
    var initials: String { String(displayName.prefix(1)).uppercased() }

    enum CodingKeys: String, CodingKey {
        case id, platform, snippet
        case leadId        = "lead_id"
        case leadName      = "lead_name"
        case contactNumber = "contact_number"
        case unreadCount   = "unread_count"
        case lastMessageAt = "last_message_at"
    }
}

struct ConversationMessage: Codable, Identifiable {
    let id: Int
    let type: String              // "sms" or "email"
    let body: String?
    let direction: String         // "inbound" | "outbound"
    let read: Bool
    let sentAt: Date?

    // SMS
    let fromNumber: String?
    let toNumber: String?
    let status: String?

    // Email
    let subject: String?
    let fromEmail: String?
    let toEmail: String?

    var isOutbound: Bool { direction == "outbound" }

    enum CodingKeys: String, CodingKey {
        case id, type, body, direction, read, status, subject
        case sentAt     = "sent_at"
        case fromNumber = "from_number"
        case toNumber   = "to_number"
        case fromEmail  = "from_email"
        case toEmail    = "to_email"
    }
}

struct ConversationThread: Codable {
    let platform: String
    let threadId: Int
    let leadId: Int?
    let leadName: String?
    let contactNumber: String?
    let messages: [ConversationMessage]

    enum CodingKeys: String, CodingKey {
        case platform, messages
        case threadId      = "thread_id"
        case leadId        = "lead_id"
        case leadName      = "lead_name"
        case contactNumber = "contact_number"
    }
}

struct ConversationsMeta: Codable {
    let page: Int
    let perPage: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page, total
        case perPage     = "per_page"
        case totalPages  = "total_pages"
    }
}

struct ConversationsResponse: Codable {
    let conversations: [Conversation]
    let meta: ConversationsMeta?
}

struct ConversationReplyResponse: Codable {
    let message: ConversationMessage
}

struct OkResponse: Codable {
    let ok: Bool
}

struct ErrorResponse: Codable {
    let error: String
    let message: String?
}
