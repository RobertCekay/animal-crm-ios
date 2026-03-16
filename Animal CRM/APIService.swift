//
//  APIService.swift
//  Animal CRM
//
//  Centralized API service for all backend communication
//

import Foundation
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var authToken: String?
    
    private var cachedProducts: [Product]?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Rails returns ISO 8601 dates with and without fractional seconds.
        // Swift's built-in .iso8601 rejects fractional seconds, so use a custom strategy.
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = withFractional.date(from: str) { return date }
            if let date = withoutFractional.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Cannot decode date: \(str)"
            )
        }
        return decoder
    }()
    
    private init() {
        // Load saved token
        loadAuthToken()
    }
    
    // MARK: - Authentication
    
    func saveAuthToken(_ token: String, user: User) {
        self.authToken = token
        self.currentUser = user
        self.isAuthenticated = true
        
        // Save to UserDefaults (use Keychain in production)
        UserDefaults.standard.set(token, forKey: "auth_token")
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }
    }
    
    func loadAuthToken() {
        if let token = UserDefaults.standard.string(forKey: "auth_token"),
           let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.authToken = token
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signOut() {
        self.authToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
        AccountManager.shared.signOut()
    }
    
    // MARK: - Request Builder
    
    private func buildRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: "\(APIConfig.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if requiresAuth, let accountId = AccountManager.shared.currentAccount?.id {
            request.setValue("\(accountId)", forHTTPHeaderField: "X-Account-Id")
        }

        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Generic Request
    
    private func performRequest<T: Decodable>(
        _ request: URLRequest
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.message ?? errorResponse.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("❌ Decoding error for \(T.self): \(error)\nRaw response: \(raw)")
            throw APIError.decodingError
        }
    }
    
    // MARK: - Login

    func login(email: String, password: String) async throws {
        struct LoginRequest: Encodable {
            let email: String
            let password: String
        }

        let body = try JSONEncoder().encode(LoginRequest(email: email, password: password))
        let request = try buildRequest(endpoint: "/api/auth/login", method: "POST", body: body, requiresAuth: false)
        let response: AuthResponse = try await performRequest(request)

        await MainActor.run {
            saveAuthToken(response.token, user: response.user)
        }

        // Fetch accounts and activate the last-used one
        let accounts = try await fetchAccounts()
        await MainActor.run {
            AccountManager.shared.load(accounts: accounts)
        }
    }

    func fetchAccounts() async throws -> [Account] {
        let request = try buildRequest(endpoint: "/api/accounts")
        let response: AccountsResponse = try await performRequest(request)
        return response.accounts
    }

    // MARK: - Jobs API
    
    func fetchTodaysJobs() async throws -> [Job] {
        let request = try buildRequest(endpoint: "/api/jobs/today")
        let response: JobsResponse = try await performRequest(request)
        return response.jobs
    }
    
    func fetchAllJobs() async throws -> [Job] {
        let request = try buildRequest(endpoint: "/api/jobs")
        let response: JobsResponse = try await performRequest(request)
        return response.jobs
    }
    
    func fetchJob(id: Int) async throws -> Job {
        let request = try buildRequest(endpoint: "/api/jobs/\(id)")
        return try await performRequest(request)
    }
    
    func updateJobStatus(id: Int, status: JobStatus) async throws -> Job {
        let body = try JSONEncoder().encode(["status": status.rawValue])
        let request = try buildRequest(endpoint: "/api/jobs/\(id)/status", method: "PATCH", body: body)
        return try await performRequest(request)
    }
    
    // MARK: - Leads API
    
    func fetchLeads() async throws -> [Lead] {
        let request = try buildRequest(endpoint: "/api/leads")
        let response: LeadsResponse = try await performRequest(request)
        return response.leads
    }

    func searchLeads(query: String) async throws -> [Lead] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let request = try buildRequest(endpoint: "/api/leads?q=\(encoded)")
        let response: LeadsResponse = try await performRequest(request)
        return response.leads
    }
    
    func createLead(name: String, phone: String?, email: String?, address: String?, notes: String?) async throws -> Lead {
        var params: [String: Any] = ["name": name]
        if let phone = phone { params["phone"] = phone }
        if let email = email { params["email"] = email }
        if let address = address { params["address"] = address }
        if let notes = notes { params["notes"] = notes }
        
        let body = try JSONSerialization.data(withJSONObject: params)
        let request = try buildRequest(endpoint: "/api/leads", method: "POST", body: body)
        return try await performRequest(request)
    }
    
    // MARK: - Time Tracking API

    func fetchActiveTimeEntry() async throws -> TimeEntry? {
        let request = try buildRequest(endpoint: "/api/time_entries/active")
        return try? await performRequest(request)
    }

    func clockIn(jobId: Int?, notes: String?, latitude: Double, longitude: Double, accuracy: Double?) async throws -> TimeEntry {
        struct ClockInRequest: Encodable {
            let job_id: Int?
            let notes: String?
            let latitude: Double
            let longitude: Double
            let accuracy: Double?
        }
        let body = try JSONEncoder().encode(ClockInRequest(
            job_id: jobId, notes: notes,
            latitude: latitude, longitude: longitude, accuracy: accuracy
        ))
        let request = try buildRequest(endpoint: "/api/time_entries/clock_in", method: "POST", body: body)
        return try await performRequest(request)
    }

    func clockOut(timeEntryId: Int, latitude: Double, longitude: Double, accuracy: Double?, notes: String?) async throws -> TimeEntry {
        struct ClockOutRequest: Encodable {
            let latitude: Double
            let longitude: Double
            let accuracy: Double?
            let notes: String?
        }
        let body = try JSONEncoder().encode(ClockOutRequest(
            latitude: latitude, longitude: longitude, accuracy: accuracy, notes: notes
        ))
        let request = try buildRequest(endpoint: "/api/time_entries/\(timeEntryId)/clock_out", method: "PATCH", body: body)
        return try await performRequest(request)
    }

    func sendLocationPing(entryId: Int, ping: LocationPingRequest) async throws -> LocationPing {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(ping)
        let request = try buildRequest(endpoint: "/api/time_entries/\(entryId)/location", method: "POST", body: body)
        return try await performRequest(request)
    }

    // MARK: - SMS API

    func fetchSmsConversations() async throws -> [SmsConversation] {
        let request = try buildRequest(endpoint: "/api/sms/conversations")
        let response: SmsConversationsResponse = try await performRequest(request)
        return response.conversations
    }

    func fetchSmsThread(conversationId: Int) async throws -> SmsThreadResponse {
        let request = try buildRequest(endpoint: "/api/sms/conversations/\(conversationId)")
        return try await performRequest(request)
    }

    func replySms(conversationId: Int, body: String) async throws -> SmsMessage {
        struct ReplyRequest: Encodable { let body: String }
        let data = try JSONEncoder().encode(ReplyRequest(body: body))
        let request = try buildRequest(endpoint: "/api/sms/conversations/\(conversationId)/reply", method: "POST", body: data)
        let response: SmsReplyResponse = try await performRequest(request)
        return response.message
    }

    func markSmsRead(conversationId: Int) async throws {
        let request = try buildRequest(endpoint: "/api/sms/conversations/\(conversationId)/mark_read", method: "POST")
        let _: [String: Bool] = try await performRequest(request)
    }

    func findOrCreateSmsConversation(phone: String) async throws -> SmsConversation {
        struct Body: Encodable { let phone: String }
        let data = try JSONEncoder().encode(Body(phone: phone))
        let request = try buildRequest(endpoint: "/api/sms/conversations", method: "POST", body: data)
        let response: SmsConversationResponse = try await performRequest(request)
        return response.conversation
    }

    // MARK: - Calls API

    func fetchCallToken(phoneLineId: Int? = nil) async throws -> CallToken {
        var endpoint = "/api/calls/token"
        if let id = phoneLineId { endpoint += "?phone_line_id=\(id)" }
        let request = try buildRequest(endpoint: endpoint)
        return try await performRequest(request)
    }

    func fetchCallHistory() async throws -> [CallRecord] {
        let request = try buildRequest(endpoint: "/api/calls")
        let response: CallsResponse = try await performRequest(request)
        return response.calls
    }

    // MARK: - Products API

    func fetchProducts() async throws -> [Product] {
        if let cached = cachedProducts { return cached }
        let request = try buildRequest(endpoint: "/api/products")
        let response: ProductsResponse = try await performRequest(request)
        cachedProducts = response.products
        return response.products
    }

    // MARK: - Invoice API

    func fetchJobInvoice(jobId: Int) async throws -> Invoice? {
        let request = try buildRequest(endpoint: "/api/jobs/\(jobId)/invoice")
        let response: InvoiceResponse? = try? await performRequest(request)
        return response?.invoice
    }

    // MARK: - Create Job

    func createJob(_ body: CreateJobRequest) async throws -> Job {
        let data = try JSONEncoder().encode(body)
        let request = try buildRequest(endpoint: "/api/jobs", method: "POST", body: data)
        return try await performRequest(request)
    }

    // MARK: - Estimates API

    func fetchEstimates() async throws -> [Estimate] {
        let request = try buildRequest(endpoint: "/api/estimates")
        let response: EstimatesResponse = try await performRequest(request)
        return response.estimates
    }

    func fetchEstimate(id: Int) async throws -> Estimate {
        let request = try buildRequest(endpoint: "/api/estimates/\(id)")
        return try await performRequest(request)
    }

    func createEstimate(_ body: CreateEstimateRequest) async throws -> Estimate {
        let data = try JSONEncoder().encode(body)
        let request = try buildRequest(endpoint: "/api/estimates", method: "POST", body: data)
        return try await performRequest(request)
    }

    func updateEstimate(id: Int, body: UpdateEstimateRequest) async throws -> Estimate {
        let data = try JSONEncoder().encode(body)
        let request = try buildRequest(endpoint: "/api/estimates/\(id)", method: "PATCH", body: data)
        return try await performRequest(request)
    }

    func sendEstimateToCustomer(id: Int) async throws -> Estimate {
        let request = try buildRequest(endpoint: "/api/estimates/\(id)/send_to_customer", method: "POST")
        return try await performRequest(request)
    }

    func convertEstimateToJob(id: Int) async throws -> Job {
        let request = try buildRequest(endpoint: "/api/estimates/\(id)/convert_to_job", method: "POST")
        return try await performRequest(request)
    }

    // MARK: - Lead Conversation API

    func fetchLeadMessages(leadId: Int) async throws -> LeadMessagesResponse {
        let request = try buildRequest(endpoint: "/api/leads/\(leadId)/messages")
        return try await performRequest(request)
    }

    func fetchPhoneLines() async throws -> [PhoneLine] {
        let request = try buildRequest(endpoint: "/api/phone_lines")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        // API may return {"phoneLines":[...]} or {"phone_lines":[...]} or a bare array
        if let wrapped = try? decoder.decode(PhoneLinesResponse.self, from: data) {
            return wrapped.phoneLines
        }
        do {
            return try decoder.decode([PhoneLine].self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("❌ fetchPhoneLines decode error: \(error)\nRaw: \(raw)")
            throw APIError.decodingError
        }
    }

    func sendLeadMessage(leadId: Int, channel: String, body: String, subject: String? = nil, phoneLineId: Int? = nil) async throws -> SendMessageResponse {
        struct SendBody: Encodable {
            let channel: String
            let body: String
            let subject: String?
            let phoneLineId: Int?
            enum CodingKeys: String, CodingKey {
                case channel, body, subject
                case phoneLineId = "phone_line_id"
            }
        }
        let data = try JSONEncoder().encode(SendBody(channel: channel, body: body, subject: subject, phoneLineId: phoneLineId))
        let request = try buildRequest(endpoint: "/api/leads/\(leadId)/send_message", method: "POST", body: data)
        return try await performRequest(request)
    }

    // MARK: - Properties API

    func fetchProperties(leadId: Int) async throws -> [Property] {
        let request = try buildRequest(endpoint: "/api/leads/\(leadId)/properties")
        let response: PropertiesResponse = try await performRequest(request)
        return response.properties
    }

    func createProperty(leadId: Int, body: CreatePropertyRequest) async throws -> Property {
        let data = try JSONEncoder().encode(body)
        let request = try buildRequest(endpoint: "/api/leads/\(leadId)/properties", method: "POST", body: data)
        let response: PropertyResponse = try await performRequest(request)
        return response.property
    }

    // MARK: - Conversations API

    func fetchConversations(query: String? = nil) async throws -> [Conversation] {
        var endpoint = "/api/conversations"
        if let q = query, !q.isEmpty,
           let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            endpoint += "?q=\(encoded)"
        }
        let request = try buildRequest(endpoint: endpoint)
        let response: ConversationsResponse = try await performRequest(request)
        return response.conversations
    }

    func fetchConversationThread(id: Int, platform: String) async throws -> ConversationThread {
        let request = try buildRequest(endpoint: "/api/conversations/\(id)/messages?platform=\(platform)")
        return try await performRequest(request)
    }

    func replyToConversation(id: Int, platform: String, body: String, subject: String? = nil, phoneLineId: Int? = nil) async throws -> ConversationMessage? {
        struct ReplyBody: Encodable {
            let platform: String
            let body: String
            let subject: String?
            let phoneLineId: Int?
            enum CodingKeys: String, CodingKey {
                case platform, body, subject
                case phoneLineId = "phone_line_id"
            }
        }
        let data = try JSONEncoder().encode(ReplyBody(platform: platform, body: body, subject: subject, phoneLineId: phoneLineId))
        let request = try buildRequest(endpoint: "/api/conversations/\(id)/reply", method: "POST", body: data)
        if platform == "sms" {
            let response: ConversationReplyResponse = try await performRequest(request)
            return response.message
        } else {
            let _: OkResponse = try await performRequest(request)
            return nil
        }
    }

    func markConversationRead(id: Int, platform: String) async throws {
        let request = try buildRequest(
            endpoint: "/api/conversations/\(id)/mark_read?platform=\(platform)",
            method: "POST"
        )
        let _: OkResponse = try await performRequest(request)
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        }
    }
}
