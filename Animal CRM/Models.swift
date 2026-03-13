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
    let propertyId: Int?
    let propertyName: String?
    let customerName: String?
    let customerPhone: String?
    let customerEmail: String?
    let notes: String?
    let totalAmount: Double?
    let isPaid: Bool
    let createdAt: Date
    let updatedAt: Date

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
        return String(format: "$%.2f", amount)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, status, address, city, state, notes
        case scheduledDate = "scheduled_date"
        case scheduledTime = "scheduled_time"
        case zipCode = "zip_code"
        case propertyId = "property_id"
        case propertyName = "property_name"
        case customerName = "customer_name"
        case customerPhone = "customer_phone"
        case customerEmail = "customer_email"
        case totalAmount = "total_amount"
        case isPaid = "is_paid"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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

// MARK: - Lead (Contact)

struct Lead: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let email: String?
    let phone: String?
    let address: String?
    let source: String?
    let status: String?
    let tags: [String]?
    let notes: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, address, source, status, tags, notes
        case createdAt = "created_at"
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
    let address: String?        // fallback only when no property selected
    let scheduledDate: String?
    let scheduledTime: String?
    let lineItems: [LineItemRequest]?

    enum CodingKeys: String, CodingKey {
        case notes, address
        case leadId = "lead_id"
        case propertyId = "property_id"
        case scheduledDate = "scheduled_date"
        case scheduledTime = "scheduled_time"
        case lineItems = "line_items"
    }
}

struct CreateEstimateRequest: Encodable {
    let leadId: Int
    let propertyId: Int?
    let notes: String?
    let lineItems: [LineItemRequest]?

    enum CodingKeys: String, CodingKey {
        case notes
        case leadId = "lead_id"
        case propertyId = "property_id"
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
    let description: String
    let quantity: Int
    let unitPrice: Double

    enum CodingKeys: String, CodingKey {
        case description, quantity
        case unitPrice = "unit_price"
    }
}

// MARK: - Local Mutable Draft (not Codable)

struct LineItemDraft: Identifiable {
    let id = UUID()
    var description: String = ""
    var quantity: Int = 1
    var unitPrice: Double = 0

    var total: Double { Double(quantity) * unitPrice }

    func toRequest() -> LineItemRequest {
        LineItemRequest(description: description, quantity: quantity, unitPrice: unitPrice)
    }
}

// MARK: - Invoice

struct Invoice: Codable, Identifiable {
    let id: Int
    let jobId: Int?
    let customerId: Int
    let customerName: String
    let totalAmount: Double
    let paidAmount: Double
    let status: InvoiceStatus
    let dueDate: Date?
    let paidAt: Date?
    let createdAt: Date
    
    var balanceDue: Double {
        totalAmount - paidAmount
    }
    
    var formattedTotal: String {
        String(format: "$%.2f", totalAmount)
    }
    
    var formattedBalance: String {
        String(format: "$%.2f", balanceDue)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case jobId = "job_id"
        case customerId = "customer_id"
        case customerName = "customer_name"
        case totalAmount = "total_amount"
        case paidAmount = "paid_amount"
        case dueDate = "due_date"
        case paidAt = "paid_at"
        case createdAt = "created_at"
    }
}

enum InvoiceStatus: String, Codable {
    case draft = "draft"
    case sent = "sent"
    case paid = "paid"
    case partiallyPaid = "partially_paid"
    case overdue = "overdue"
}

// MARK: - Property (service location)

struct Property: Codable, Identifiable {
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

// MARK: - SMS

struct SmsConversation: Codable, Identifiable {
    let id: Int
    let contactNumber: String
    let leadId: Int?
    let leadName: String
    let snippet: String?
    let unreadCount: Int
    let lastMessageAt: Date?
    let phoneLineId: Int?
    let createdAt: Date

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
    let status: String
    let fromNumber: String?
    let toNumber: String?
    let read: Bool
    let sentAt: Date

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

struct LeadsResponse: Codable {
    let leads: [Lead]
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

struct ErrorResponse: Codable {
    let error: String
    let message: String?
}
