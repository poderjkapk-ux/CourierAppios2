import SwiftUI

struct ProfileView: View {
    @AppStorage("cookie") var savedCookie: String = ""
    @StateObject private var networkManager = NetworkManager.shared
    
    @State private var profile: CourierProfile? = nil
    @State private var motivators: [Motivator] = []
    @State private var isLoading = true
    
    // Состояния для формы обратной связи
    @State private var showFeedbackDialog = false
    @State private var feedbackText = ""
    @State private var isFeedbackSending = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Завантаження профілю...")
            } else if let profile = profile {
                ScrollView {
                    VStack(spacing: 24) {
                        // Аватарка и базовые данные
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [AppColors.primary, AppColors.secondary]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 100, height: 100)
                                    .shadow(radius: 8)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                            
                            Text(profile.name)
                                .font(.title)
                                .fontWeight(.heavy)
                                .foregroundColor(AppColors.primary)
                            
                            Text(profile.phone)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Статистика (Комиссия, Рейтинг, Баланс)
                        HStack {
                            ProfileStatItem(label: "Комісія", value: "\(String(format: "%.1f", profile.commissionRate ?? 0))%", color: AppColors.primary)
                            
                            Divider().frame(height: 40)
                            
                            ProfileStatItem(label: "Рейтинг", value: "\(String(format: "%.1f", profile.rating ?? 5.0))", color: AppColors.warning)
                            
                            Divider().frame(height: 40)
                            
                            ProfileStatItem(label: "Баланс", value: "\(Int(profile.balance ?? 0)) ₴", color: AppColors.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 5)
                        
                        // Мотиваторы (Цели и бонусы)
                        if !motivators.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundColor(.yellow)
                                    Text("Ваші цілі та бонуси")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                ForEach(motivators) { motivator in
                                    MotivatorCardView(motivator: motivator)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Статистика отзывов
                        HStack(spacing: 12) {
                            Image(systemName: "star.bubble.fill")
                                .foregroundColor(AppColors.primary)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text("Отримано відгуків")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("\(profile.ratingCount ?? 0)")
                                    .font(.headline)
                                    .foregroundColor(AppColors.primary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 3)
                        
                        // Кнопка поддержки
                        Button(action: { showFeedbackDialog = true }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Написати в підтримку")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 99/255, green: 102/255, blue: 241/255)) // Indigo
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        
                        // Кнопка выхода
                        Button(action: logout) {
                            Text("Вийти з акаунта")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(AppColors.error)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.error, lineWidth: 2)
                                )
                        }
                        .padding(.bottom, 30)
                    }
                    .padding()
                }
            } else {
                Text("Помилка завантаження")
                    .foregroundColor(AppColors.error)
            }
            
            // Простой Toast для уведомлений (вместо Android Toast)
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: showToast)
            }
        }
        .onAppear {
            Task { await loadData() }
        }
        // Модальное окно обратной связи
        .alert("Служба підтримки", isPresented: $showFeedbackDialog) {
            TextField("Опишіть вашу проблему...", text: $feedbackText)
            Button("Скасувати", role: .cancel) { feedbackText = "" }
            Button("Відправити") { sendFeedback() }
        } message: {
            Text("Ми обов'язково вам допоможемо.")
        }
    }
    
    // MARK: - Методы
    private func loadData() async {
        isLoading = true
        do {
            async let fetchProfile = networkManager.getProfile(cookie: savedCookie)
            // Если вы добавили getMotivators в NetworkManager:
            // async let fetchMotivators = networkManager.getMotivators(cookie: savedCookie)
            
            self.profile = try await fetchProfile
            // self.motivators = try await fetchMotivators 
            // Пока оставляем пустым, если метод еще не написан
        } catch {
            print("Помилка завантаження профілю: \(error)")
        }
        isLoading = false
    }
    
    private func sendFeedback() {
        guard !feedbackText.isEmpty else { return }
        isFeedbackSending = true
        
        // Здесь должен быть вызов NetworkManager.shared.sendFeedback
        // Так как это демонстрация, имитируем отправку:
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isFeedbackSending = false
            feedbackText = ""
            toastMessage = "✅ Дякуємо! Звернення відправлено."
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showToast = false
            }
        }
    }
    
    private func logout() {
        // Очищаем токен. ContentView автоматически выбросит нас на LoginView
        savedCookie = ""
        networkManager.disconnectWebSocket()
    }
}

// MARK: - Компоненты UI
struct ProfileStatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Карточка мотиватора
struct MotivatorCardView: View {
    let motivator: Motivator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.yellow)
                Text(motivator.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            if let desc = motivator.description {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Прогресс бар
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(AppColors.secondary)
                        .frame(width: geometry.size.width * CGFloat(motivator.progressPercent) / 100, height: 10)
                }
            }
            .frame(height: 10)
            .padding(.vertical, 4)
            
            HStack {
                Text("Прогрес: \(motivator.currentOrders) / \(motivator.targetOrders)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                if let deadline = motivator.deadlineDate {
                    Text("До: \(formatDate(deadline))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [AppColors.primary, Color.black]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .shadow(radius: 4)
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy"
            return displayFormatter.string(from: date)
        }
        return isoString
    }
}
