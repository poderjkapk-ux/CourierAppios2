import SwiftUI

struct HistoryView: View {
    @State private var orders: [HistoryOrder] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Фильтр по датам: "Всі", "Сьогодні", "Вчора"
    @State private var selectedFilter = "Сьогодні"
    let filters = ["Сьогодні", "Вчора", "Всі"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Селектор фильтра
                Picker("Фільтр", selection: $selectedFilter) {
                    ForEach(filters, id: \.self) { filter in
                        Text(filter).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color(.systemGroupedBackground))
                
                if isLoading {
                    Spacer()
                    ProgressView("Завантаження історії...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Спробувати знову") {
                            Task { await fetchHistory() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    Spacer()
                } else if filteredOrders.isEmpty {
                    Spacer()
                    Text("За цей період замовлень не знайдено")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        // Секция со статистикой за выбранный период
                        Section(header: Text("Статистика за період")) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Замовлень:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text("\(filteredOrders.count)")
                                        .font(.headline)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Заробіток:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text("\(String(format: "%.2f", totalEarnings)) ₴")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        
                        // Список заказов
                        Section(header: Text("Список замовлень")) {
                            ForEach(filteredOrders) { order in
                                HistoryOrderRow(order: order)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .refreshable {
                        await fetchHistory()
                    }
                }
            }
            .navigationTitle("Історія")
            .onAppear {
                Task { await fetchHistory() }
            }
        }
    }
    
    // MARK: - Логика фильтрации
    
    private var filteredOrders: [HistoryOrder] {
        let today = getFormattedDate(Date())
        let yesterday = getFormattedDate(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        
        switch selectedFilter {
        case "Сьогодні":
            return orders.filter { $0.date.hasPrefix(today) }
        case "Вчора":
            return orders.filter { $0.date.hasPrefix(yesterday) }
        default:
            return orders
        }
    }
    
    private var totalEarnings: Double {
        filteredOrders.reduce(0) { $0 + $1.price }
    }
    
    // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Формат dd.MM.yyyy для исключения совпадений в разные годы
    private func getFormattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Загрузка данных
    
    private func fetchHistory() async {
        let cookie = UserDefaults.standard.string(forKey: "courier_token") ?? ""
        if cookie.isEmpty {
            self.errorMessage = "Потрібна авторизація"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedOrders = try await NetworkManager.shared.getHistory(cookie: cookie)
            DispatchQueue.main.async {
                // Сортируем: сначала новые
                self.orders = fetchedOrders.sorted(by: { $0.id > $1.id })
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Не вдалося завантажити історію. Перевірте з'єднання."
                self.isLoading = false
            }
        }
    }
}

// MARK: - Вспомогательная View для строки заказа

struct HistoryOrderRow: View {
    let order: HistoryOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(order.id)")
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                
                Spacer()
                
                Text(order.date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(order.address)
                .font(.subheadline)
                .lineLimit(2)
            
            HStack {
                Text(order.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .cornerRadius(10)
                
                Spacer()
                
                Text("\(String(format: "%.2f", order.price)) ₴")
                    .font(.system(.subheadline, design: .monospaced))
                    .bold()
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch order.status.lowercased() {
        case "completed", "виконано": return .green
        case "cancelled", "скасовано": return .red
        default: return .orange
        }
    }
}
