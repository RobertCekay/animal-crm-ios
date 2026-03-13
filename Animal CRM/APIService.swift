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
        decoder.dateDecodingStrategy = .iso8601
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
            print("❌ Decoding error: \(error)")
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
