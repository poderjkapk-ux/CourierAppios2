import SwiftUI

struct HistoryView: View {
    @AppStorage("cookie") var savedCookie: String = ""
    @StateObject private var networkManager = NetworkManager.shared
    
    // Для закриття екрану, якщо він відкритий поверх інших
    @Environment(\.presentationMode) var presentationMode
    
    @State private var history: [HistoryOrder] = []
    @State private var isLoading = false
    
    // Стан фільтрів
    @State private var currentFilter = "Сьогодні"
    private let filters = ["Сьогодні", "Вчора", "Обрана дата", "Всі"]
    
    // Стан для вибору кастомної дати
    @State private var showDatePicker = false
    @State private var selectedDate = Date()
    @State private var customDateString: String? = nil
    
    // Обчислювана властивість для фільтрації історії
    var filteredHistory: [HistoryOrder] {
        let todayStr = getFormattedDate(Date())
        let yesterdayStr = getFormattedDate(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        
        return history.filter { order in
            switch currentFilter {
            case "Всі":
                return true
            case "Сьогодні":
                return order.date.hasPrefix(todayStr)
            case "Вчора":
                return order.date.hasPrefix(yesterdayStr)
            case "Обрана дата":
                guard let custom = customDateString else { return true }
                return order.date.hasPrefix(custom)
            default:
                return true
            }
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Верхня панель (TopBar)
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Text("Історія та Доходи")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.primary)
                        .padding(.leading, 8)
                    
                    Spacer()
                }
                .padding()
                .background(Color.white)
                
                // MARK: - Рядок фільтрів (Tabs)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            let isSelected = currentFilter == filter
                            let displayText = (filter == "Обрана дата" && customDateString != nil) ? customDateString! : filter
                            
                            Button(action: {
                                if filter == "Обрана дата" {
                                    showDatePicker = true
                                } else {
                                    currentFilter = filter
                                    customDateString = nil
                                }
                            }) {
                                Text(displayText)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? AppColors.primary : Color.white)
                                    .foregroundColor(isSelected ? .white : AppColors.primary)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isSelected ? AppColors.primary : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                // MARK: - Картка підсумків (Summary)
                SummaryCard(filteredHistory: filteredHistory)
                    .padding(.horizontal)
                
                // MARK: - Список замовлень
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if filteredHistory.isEmpty && !isLoading {
                            VStack(spacing: 20) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(Color.gray.opacity(0.3))
                                Text("Немає замовлень за цей період")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(filteredHistory) { order in
                                HistoryOrderCardView(order: order)
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await fetchHistory()
                }
            }
        }
        .onAppear {
            Task { await fetchHistory() }
        }
        // Модальне вікно вибору дати
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                VStack {
                    DatePicker("Оберіть дату", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .tint(AppColors.primary)
                    Spacer()
                }
                .navigationTitle("Вибір дати")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") {
                            customDateString = getFormattedDate(selectedDate)
                            currentFilter = "Обрана дата"
                            showDatePicker = false
                        }
                        .fontWeight(.bold)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Скасувати") {
                            showDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Логіка
    private func fetchHistory() async {
        isLoading = true
        do {
            history = try await networkManager.getHistory(cookie: savedCookie)
        } catch {
            print("Помилка завантаження історії: \(error)")
        }
        isLoading = false
    }
    
    private func getFormattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }
}

// MARK: - Картка підсумків (Фінансова статистика)
struct SummaryCard: View {
    let filteredHistory: [HistoryOrder]
    
    var body: some View {
        let deliveredOrders = filteredHistory.filter { $0.status == "delivered" }
        let completedCount = deliveredOrders.count
        let totalEarned = deliveredOrders.reduce(0.0) { $0 + $1.price }
        let totalCommission = deliveredOrders.reduce(0.0) { $0 + ($1.commission ?? 0.0) }
        let netProfit = totalEarned - totalCommission
        
        VStack(spacing: 16) {
            HStack {
                Text("Чистий прибуток")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(completedCount) замовлень")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            }
            
            HStack {
                Text("₴ \(String(format: "%.2f", netProfit))")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Дохід з доставок")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("+ ₴\(String(format: "%.2f", totalEarned))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Комісія сервісу")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("- ₴\(String(format: "%.2f", totalCommission))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.error)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(gradient: Gradient(colors: [AppColors.primary, Color(red: 15/255, green: 23/255, blue: 42/255)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(20)
        .shadow(color: AppColors.primary.opacity(0.2), radius: 12, y: 5)
    }
}

// MARK: - Картка окремого замовлення в історії
struct HistoryOrderCardView: View {
    let order: HistoryOrder
    
    var body: some View {
        let isDelivered = order.status == "delivered"
        
        VStack(spacing: 16) {
            HStack {
                Text("Замовлення #\(order.id)")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.primary)
                Spacer()
                Text(order.date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.08))
                        .frame(width: 32, height: 32)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.primary)
                }
                Text(order.address)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            
            HStack(alignment: .bottom) {
                // Статус
                Text(isDelivered ? "Виконано" : "Скасовано")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isDelivered ? AppColors.secondary : AppColors.error)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isDelivered ? AppColors.secondary : AppColors.error).opacity(0.1))
                    .cornerRadius(8)
                
                Spacer()
                
                // Гроші
                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(String(format: "%.0f", order.price)) ₴")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(isDelivered ? AppColors.secondary : AppColors.textSecondary)
                    
                    if isDelivered, let commission = order.commission, commission > 0 {
                        Text("Комісія: -\(String(format: "%.0f", commission)) ₴")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.error.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppColors.error.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}
