import SwiftUI

struct MainTabView: View {
    // Стан для вибору активної вкладки (аналог selectedItem у Compose)
    @State private var selectedTab = 0
    
    // Підключаємо NetworkManager для відстеження подій (наприклад, бейджів на іконках)
    @ObservedObject private var networkManager = NetworkManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Вкладка 1: Список доступних замовлень
            // Аналог "orders" / Icons.Default.List у Screens.kt
            NavigationView {
                OrdersView()
            }
            .tabItem {
                Label("Замовлення", systemImage: "list.bullet")
            }
            .tag(0)
            
            // Вкладка 2: Активні замовлення в роботі
            // Аналог "active" / Icons.Default.ShoppingBag у Screens.kt
            NavigationView {
                ActiveOrderView()
            }
            .tabItem {
                Label("Активні", systemImage: "bag.fill")
            }
            .tag(1)
            
            // Вкладка 3: Профіль кур'єра та статистика
            // Аналог "profile" / Icons.Default.Person у Screens.kt
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Профіль", systemImage: "person.fill")
            }
            .tag(2)
        }
        // Встановлюємо акцентний колір для активної вкладки (синій, як у вашому Android UI)
        .accentColor(.blue)
        .onReceive(networkManager.wsEventPublisher) { event in
            handleGlobalEvents(event)
        }
    }
    
    /// Обробка глобальних повідомлень, що впливають на навігацію
    private func handleGlobalEvents(_ event: WSEvent) {
        switch event {
        case .newOrder:
            // Якщо прийшло нове замовлення, можна автоматично перемкнути на вкладку списку
            // або просто подати вібро-сигнал
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
        case .directOffer:
            // Для персональних оферів перемикаємо на вкладку замовлень
            selectedTab = 0
            
        default:
            break
        }
    }
}
