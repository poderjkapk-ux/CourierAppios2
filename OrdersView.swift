import SwiftUI

// MARK: - Дизайн-система (Кольори)
struct AppColors {
    static let primary = Color(red: 30/255, green: 41/255, blue: 59/255) // 1E293B
    static let secondary = Color(red: 16/255, green: 185/255, blue: 129/255) // 10B981
    static let background = Color(red: 248/255, green: 250/255, blue: 252/255) // F8FAFC
    static let error = Color.red
    static let warning = Color.orange
    static let textSecondary = Color.gray
}

struct OrdersView: View {
    @AppStorage("cookie") var savedCookie: String = ""
    @StateObject private var networkManager = NetworkManager.shared
    
    @State private var orders: [OpenOrder] = []
    @State private var announcements: [Announcement] = []
    @State private var isOnline: Bool = false
    @State private var isLoading = false
    
    // Для демо-симуляції координат (в реальному житті беремо з LocationManager)
    @State private var currentLat: Double = 46.4825
    @State private var currentLon: Double = 30.7233
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: Власна панель навігації (TopBar)
                HStack {
                    Text("Доступні")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.primary)
                    
                    Spacer()
                    
                    // Кнопка статусу Онлайн/Офлайн
                    Button(action: toggleStatus) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isOnline ? AppColors.secondary : AppColors.textSecondary)
                                .frame(width: 10, height: 10)
                            Text(isOnline ? "Онлайн" : "Офлайн")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(isOnline ? AppColors.secondary : AppColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            (isOnline ? AppColors.secondary : AppColors.textSecondary).opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                // MARK: Список замовлень з Pull-to-refresh
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Оголошення (Announcements)
                        ForEach(announcements) { ann in
                            AnnouncementCardView(announcement: ann) { id in
                                dismissAnnouncement(id)
                            }
                        }
                        
                        if orders.isEmpty && !isLoading {
                            VStack(spacing: 20) {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(Color.gray.opacity(0.3))
                                Text("Зараз немає замовлень")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 100)
                        } else {
                            // Замовлення
                            ForEach(orders) { order in
                                OrderCardView(order: order) { jobId in
                                    acceptOrder(jobId: jobId)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await fetchOrders()
                }
            }
        }
        .onAppear {
            Task {
                await fetchOrders()
                await fetchProfileStatus()
            }
        }
        // Оновлюємо список, якщо прийшов PUSH через WebSocket
        .onReceive(networkManager.wsEventPublisher) { event in
            if case .newOrder = event {
                Task { await fetchOrders() }
            }
        }
    }
    
    // MARK: - Мережеві запити
    private func fetchOrders() async {
        isLoading = true
        do {
            orders = try await networkManager.getOpenOrders(cookie: savedCookie, lat: currentLat, lon: currentLon)
            // announcements = try await networkManager.getAnnouncements(...) // розкоментуйте, якщо додали цей метод
        } catch {
            print("Помилка завантаження замовлень: \(error)")
        }
        isLoading = false
    }
    
    private func fetchProfileStatus() async {
        do {
            let profile = try await networkManager.getProfile(cookie: savedCookie)
            isOnline = profile.isOnline
        } catch {
            print("Помилка завантаження профілю: \(error)")
        }
    }
    
    private func toggleStatus() {
        Task {
            do {
                let response = try await networkManager.toggleStatus(cookie: savedCookie)
                isOnline = response.isOnline
            } catch {
                print("Помилка зміни статусу: \(error)")
            }
        }
    }
    
    private func acceptOrder(jobId: Int) {
        Task {
            do {
                let response = try await networkManager.acceptOrder(cookie: savedCookie, jobId: jobId)
                if response.status == "ok" {
                    // Якщо успішно взяли замовлення - вібруємо і оновлюємо список
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    await fetchOrders()
                }
            } catch {
                print("Помилка прийняття замовлення: \(error)")
            }
        }
    }
    
    private func dismissAnnouncement(_ id: Int) {
        withAnimation {
            announcements.removeAll { $0.id == id }
        }
        // Можна додати запит на бекенд для приховування
    }
}

// MARK: - Картка Оголошення
struct AnnouncementCardView: View {
    let announcement: Announcement
    let onDismiss: (Int) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(announcement.title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(announcement.message)
                    .font(.subheadline)
                    .foregroundColor(AppColors.primary.opacity(0.8))
            }
            Spacer()
            
            Button(action: { onDismiss(announcement.id) }) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Картка Замовлення
struct OrderCardView: View {
    let order: OpenOrder
    let onAccept: (Int) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Компактна частина
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.restaurantName)
                            .font(.title3)
                            .fontWeight(.heavy)
                            .foregroundColor(AppColors.primary)
                        if !isExpanded {
                            Text(order.restaurantAddress)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    
                    Text("\(Int(order.fee)) ₴")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(AppColors.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.secondary.opacity(0.1))
                        .cornerRadius(12)
                }
                
                HStack(spacing: 8) {
                    // Бейдж оплати
                    Text(order.paymentType == "prepaid" ? "✨ Оплачено" : "💸 Готівка")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(order.paymentType == "prepaid" ? AppColors.secondary : AppColors.warning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((order.paymentType == "prepaid" ? AppColors.secondary : AppColors.warning).opacity(0.15))
                        .cornerRadius(8)
                    
                    if let dist = order.distToRest {
                        Text("🛵 ~\(String(format: "%.1f", dist)) км")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.primary.opacity(0.08))
                            .cornerRadius(8)
                    }
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            .padding(20)
            .background(Color.white)
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            
            // Розгорнута частина
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                    
                    AddressRowView(icon: "mappin.and.ellipse", text: order.restaurantAddress, label: "Забрати")
                    
                    // Імітація лінії між адресами
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                        .padding(.leading, 11)
                        .padding(.vertical, -10)
                    
                    AddressRowView(icon: "house.fill", text: order.dropoffAddress, label: "Доставити")
                    
                    if let comment = order.comment, !comment.isEmpty {
                        Text("📝 Коментар: \(comment)")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    if let trip = order.distTrip {
                        Text("🧭 Маршрут: ~\(trip) км")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    // Кастомний слайдер "Свайп щоб прийняти"
                    SwipeToAcceptButton(text: "Свайпніть, щоб прийняти >>>") {
                        onAccept(order.id)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(Color.white)
            }
        }
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Рядок адреси з іконкою
struct AddressRowView: View {
    let icon: String
    let text: String
    let label: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                Text(text)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Кастомна кнопка "Свайп щоб прийняти"
struct SwipeToAcceptButton: View {
    let text: String
    let onAccept: () -> Void
    
    @State private var offset: CGFloat = 0
    let buttonHeight: CGFloat = 56
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Фон
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.primary.opacity(0.15))
                
                // Текст
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, buttonHeight) // щоб текст не наїжджав на повзунок
                
                // Повзунок
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.primary)
                    .frame(width: buttonHeight, height: buttonHeight)
                    .padding(4)
                    .overlay(
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Обмежуємо рух повзунка
                                let maxDrag = geometry.size.width - buttonHeight - 8
                                if value.translation.width > 0 && value.translation.width < maxDrag {
                                    offset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                let maxDrag = geometry.size.width - buttonHeight - 8
                                // Якщо протягнули більше ніж на 70%
                                if offset > maxDrag * 0.7 {
                                    withAnimation(.spring()) { offset = maxDrag }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onAccept()
                                        // Повертаємо назад (на випадок помилки мережі)
                                        withAnimation(.spring()) { offset = 0 }
                                    }
                                } else {
                                    // Повертаємо на початок
                                    withAnimation(.spring()) { offset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: buttonHeight + 8)
    }
}
