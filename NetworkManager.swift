import Foundation
import Combine

// MARK: - 1. МОДЕЛИ ДАНИХ (Models)

struct EmptyRequest: Codable {}

struct Announcement: Codable, Identifiable {
    let id: Int
    let title: String
    let message: String
    let style: String
}

struct Motivator: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let targetOrders: Int
    let currentOrders: Int
    let periodDays: Int
    let rewardDays: Int
    let rewardCommission: Double
    let status: String
    let deadlineDate: String?
    let rewardEndDate: String?
    let progressPercent: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case targetOrders = "target_orders"
        case currentOrders = "current_orders"
        case periodDays = "period_days"
        case rewardDays = "reward_days"
        case rewardCommission = "reward_commission"
        case deadlineDate = "deadline_date"
        case rewardEndDate = "reward_end_date"
        case progressPercent = "progress_percent"
    }
}

struct OpenOrder: Codable, Identifiable {
    let id: Int
    let restaurantName: String
    let restaurantAddress: String
    let dropoffAddress: String
    let fee: Double
    let price: Double
    let distToRest: Double?
    let distTrip: String?
    let paymentType: String
    let isReturn: Bool
    let comment: String?
    let readyAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, fee, price, comment
        case restaurantName = "restaurant_name"
        case restaurantAddress = "restaurant_address"
        case dropoffAddress = "dropoff_address"
        case distToRest = "dist_to_rest"
        case distTrip = "dist_trip"
        case paymentType = "payment_type"
        case isReturn = "is_return"
        case readyAt = "estimated_ready_at"
    }
}

struct ActiveJobSummary: Codable, Identifiable {
    let id: Int
    let status: String
    let partnerName: String
    let customerAddress: String
    let deliveryFee: Double
    let orderPrice: Double
    let paymentType: String
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case partnerName = "partner_name"
        case customerAddress = "customer_address"
        case deliveryFee = "delivery_fee"
        case orderPrice = "order_price"
        case paymentType = "payment_type"
    }
}

struct ActiveJobsListResponse: Codable {
    let active: Bool
    let jobs: [ActiveJobSummary]
}

struct ActiveJobResponse: Codable {
    let active: Bool
    let job: ActiveJobDetail?
}

struct ActiveJobDetail: Codable, Identifiable {
    let id: Int
    let status: String
    let serverStatus: String
    let isReady: Bool
    let readyAt: String?
    let assignedAt: String?
    let pickedUpAt: String?
    let deliveredAt: String?
    let completedAt: String?
    let partnerName: String
    let partnerAddress: String
    let partnerPhone: String?
    let customerAddress: String
    let customerLat: Double?
    let customerLon: Double?
    let customerPhone: String
    let customerName: String?
    let comment: String?
    let orderPrice: Double
    let deliveryFee: Double
    let paymentType: String
    let isReturnRequired: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, status, comment
        case serverStatus = "server_status"
        case isReady = "is_ready"
        case readyAt = "estimated_ready_at"
        case assignedAt = "assigned_at"
        case pickedUpAt = "picked_up_at"
        case deliveredAt = "delivered_at"
        case completedAt = "completed_at"
        case partnerName = "partner_name"
        case partnerAddress = "partner_address"
        case partnerPhone = "partner_phone"
        case customerAddress = "customer_address"
        case customerLat = "customer_lat"
        case customerLon = "customer_lon"
        case customerPhone = "customer_phone"
        case customerName = "customer_name"
        case orderPrice = "order_price"
        case deliveryFee = "delivery_fee"
        case paymentType = "payment_type"
        case isReturnRequired = "is_return_required"
    }
}

struct StatusResponse: Codable {
    let status: String
    let message: String?
}

struct ToggleResponse: Codable {
    let isOnline: Bool
    
    enum CodingKeys: String, CodingKey {
        case isOnline = "is_online"
    }
}

struct ChatMessage: Codable {
    let role: String
    let text: String
    let time: String
}

struct SendMessageResponse: Codable {
    let status: String
}

struct HistoryOrder: Codable, Identifiable {
    let id: Int
    let date: String
    let address: String
    let price: Double
    let status: String
    let commission: Double?
}

struct CourierProfile: Codable, Identifiable {
    let id: Int
    let name: String
    let phone: String
    let balance: Double?
    let commissionRate: Double?
    let rating: Double?
    let ratingCount: Int?
    let isOnline: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, phone, balance, rating
        case commissionRate = "commission_rate"
        case ratingCount = "rating_count"
        case isOnline = "is_online"
    }
}

struct AppUpdateResponse: Codable {
    let success: Bool
    let app: String
    let latestVersionCode: Int
    let latestVersionName: String
    let downloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case success, app
        case latestVersionCode = "latest_version_code"
        case latestVersionName = "latest_version_name"
        case downloadUrl = "download_url"
    }
}

// MARK: - События WebSocket
enum WSEvent {
    case authError
    case newOrder
    case jobUpdate
    case jobReady
    case directOffer(String)
}


// MARK: - 2. ІНТЕРФЕЙС API (NetworkManager)

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let baseURL = "https://restify.site"
    private let wsURL = "wss://restify.site/ws/courier"
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var currentWSCookie: String?
    
    let wsEventPublisher = PassthroughSubject<WSEvent, Never>()
    
    private init() {}
    
    // Вспомогательный метод для Form-Url-Encoded (как в Retrofit @FormUrlEncoded)
    private func createFormBody(parameters: [String: String]) -> Data {
        let parameterArray = parameters.map { key, value -> String in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(escapedKey)=\(escapedValue)"
        }
        return parameterArray.joined(separator: "&").data(using: .utf8) ?? Data()
    }
    
    private func createRequest(path: String, method: String = "GET", cookie: String? = nil, isForm: Bool = false, body: Data? = nil) -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            fatalError("Invalid URL: \(baseURL)\(path)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if isForm {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        if let cookie = cookie {
            request.setValue("courier_token=\(cookie)", forHTTPHeaderField: "Cookie")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: REST API Calls
    
    func login(phone: String, password: String) async throws -> String? {
        let body = createFormBody(parameters: ["phone": phone, "password": password])
        let request = createRequest(path: "/api/courier/login", method: "POST", isForm: true, body: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
            if let headers = httpResponse.allHeaderFields as? [String: String],
               let setCookie = headers["Set-Cookie"], setCookie.contains("courier_token") {
                let parts = setCookie.split(separator: ";")
                if let tokenPart = parts.first {
                    return String(tokenPart).replacingOccurrences(of: "courier_token=", with: "")
                }
            }
        }
        return nil
    }
    
    func getOpenOrders(cookie: String, lat: Double, lon: Double) async throws -> [OpenOrder] {
        let request = createRequest(path: "/api/courier/open_orders?lat=\(lat)&lon=\(lon)", cookie: cookie)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([OpenOrder].self, from: data)
    }
    
    func getDirectOffers(cookie: String) async throws -> [OpenOrder] {
        let request = createRequest(path: "/api/courier/direct_offers", cookie: cookie)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([OpenOrder].self, from: data)
    }
    
    func getActiveJob(cookie: String, jobId: Int? = nil) async throws -> ActiveJobResponse {
        var path = "/api/courier/active_job"
        if let jId = jobId { path += "?job_id=\(jId)" }
        let request = createRequest(path: path, cookie: cookie)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ActiveJobResponse.self, from: data)
    }
    
    func getActiveJobs(cookie: String) async throws -> ActiveJobsListResponse {
        let request = createRequest(path: "/api/courier/active_jobs", cookie: cookie)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ActiveJobsListResponse.self, from: data)
    }
    
    func acceptOrder(cookie: String, jobId: Int) async throws -> StatusResponse {
        let body = createFormBody(parameters: ["job_id": "\(jobId)"])
        let request = createRequest(path: "/api/courier/accept_order", method: "POST", cookie: cookie, isForm: true, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
    
    func declineDirectOrder(cookie: String, jobId: Int) async throws -> StatusResponse {
        let body = createFormBody(parameters: ["job_id": "\(jobId)"])
        let request = createRequest(path: "/api/courier/decline_direct_order", method: "POST", cookie: cookie, isForm: true, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
    
    func arrivedAtPickup(cookie: String, jobId: Int) async throws -> StatusResponse {
        let body = createFormBody(parameters: ["job_id": "\(jobId)"])
        let request = createRequest(path: "/api/courier/arrived_pickup", method: "POST", cookie: cookie, isForm: true, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
    
    func updateJobStatus(cookie: String, jobId: Int, status: String) async throws -> StatusResponse {
        let body = createFormBody(parameters: ["job_id": "\(jobId)", "status": status])
        let request = createRequest(path: "/api/courier/update_job_status", method: "POST", cookie: cookie, isForm: true, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
    
    func sendLocation(cookie: String, lat: Double, lon: Double) async throws -> StatusResponse {
        let body = createFormBody(parameters: ["lat": "\(lat)", "lon": "\(lon)"])
        let request = createRequest(path: "/api/courier/location", method: "POST", cookie: cookie, isForm: true, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
    
    func sendFcmToken(cookie: String, token: String) async throws -> StatusResponse {
        let body = createFormBody(parameters: ["token": token])
        let request = createRequest(path: "/api/courier/fcm_token", method: "POST", cookie: cookie, isForm: true, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
    
    func toggleStatus(cookie: String) async throws -> ToggleResponse {
        // Тело пустое, но нужен JSON, как в Kotlin @Body empty: EmptyRequest
        let body = try? JSONEncoder().encode(EmptyRequest())
        let request = createRequest(path: "/api/courier/toggle_status", method: "POST", cookie: cookie, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ToggleResponse.self, from: data)
    }
    
    func getChatMessages(cookie: String, jobId: Int) async throws -> [ChatMessage] {
        let request = createRequest(path: "/api/chat/history/\(jobId)", cookie: cookie)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([ChatMessage].self, from: data)
    }
    
    func sendChatMessage(cookie: String, jobId: Int, message: String) async throws -> SendMessageResponse {
        let body = createFormBody(parameters: ["job_id": "\(jobId)", "message": message, "role": "courier"])
        let request = createRequest(path: "/api/chat/send", method: "POST", cookie: cookie, isForm: true, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SendMessageResponse.self, from: data)
    }
    
    func getProfile(cookie: String) async throws -> CourierProfile {
        let request = createRequest(path: "/api/courier/profile", cookie: cookie)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(CourierProfile.self, from: data)
    }
    
    func getHistory(cookie: String) async throws -> [HistoryOrder] {
        let request = createRequest(path: "/api/courier/history", cookie: cookie)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([HistoryOrder].self, from: data)
    }
    
    // MARK: - 3. МЕНЕДЖЕР WEBSOCKET
    
    func connectWebSocket(cookie: String) {
        if webSocketTask != nil { return }
        self.currentWSCookie = cookie
        
        guard let url = URL(string: wsURL) else { return }
        var request = URLRequest(url: url)
        request.setValue("courier_token=\(cookie)", forHTTPHeaderField: "Cookie")
        
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        print("WebSocket: Connected")
        startPingTimer()
        receiveWebSocketMessage()
    }
    
    func disconnectWebSocket() {
        stopPingTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        currentWSCookie = nil
        print("WebSocket: Disconnected manually")
    }
    
    private func startPingTimer() {
        stopPingTimer()
        // Пинг каждые 15 секунд, как в Android (delay(15000))
        DispatchQueue.main.async {
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                self?.sendPing()
            }
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private func sendPing() {
        let message = URLSessionWebSocketTask.Message.string("ping")
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket Ping Error: \(error)")
                self.reconnectWebSocket()
            }
        }
    }
    
    private func reconnectWebSocket() {
        webSocketTask?.cancel()
        webSocketTask = nil
        if let cookie = currentWSCookie {
            print("WebSocket: Attempting to reconnect...")
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.connectWebSocket(cookie: cookie)
            }
        }
    }
    
    private func receiveWebSocketMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("WebSocket Message received: \(text)")
                    if text != "pong" {
                        self.handleIncomingMessage(text)
                    }
                case .data(_): break
                @unknown default: break
                }
                self.receiveWebSocketMessage()
                
            case .failure(let error):
                print("WebSocket Closed/Error: \(error.localizedDescription)")
                self.reconnectWebSocket()
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "auth_error":
                self.wsEventPublisher.send(.authError)
            case "new_order":
                self.wsEventPublisher.send(.newOrder)
            case "job_update":
                self.wsEventPublisher.send(.jobUpdate)
            case "job_ready":
                self.wsEventPublisher.send(.jobReady)
            case "direct_offer":
                self.wsEventPublisher.send(.directOffer(text))
            default:
                break
            }
        }
    }
    
    func sendLocationWS(lat: Double, lon: Double) {
        let jsonString = "{\"type\": \"init_location\", \"lat\": \(lat), \"lon\": \(lon)}"
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error { print("WS Location error: \(error)") }
        }
    }
}
