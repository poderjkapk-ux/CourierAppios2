import SwiftUI

struct ContentView: View {
    // Слідкуємо за токеном авторизації
    @AppStorage("cookie") var savedCookie: String = ""
    
    // Підключаємо менеджери
    @StateObject private var locationManager = LocationManager()
    @StateObject private var networkManager = NetworkManager.shared
    
    var body: some View {
        Group {
            if savedCookie.isEmpty {
                // Якщо токена немає — показуємо екран входу
                LoginView()
            } else {
                // Якщо токен є — показуємо головний інтерфейс з табами
                MainTabView()
                    .onAppear {
                        prepareApp()
                    }
            }
        }
        // Слухаємо події від WebSocket (наприклад, помилка авторизації)
        .onReceive(networkManager.wsEventPublisher) { event in
            handleWSEvent(event)
        }
    }
    
    /// Початкові налаштування при вході в додаток
    private func prepareApp() {
        // 1. Запитуємо дозволи на геолокацію (Always), як у LocationTracker.kt
        locationManager.requestPermissions()
        
        // 2. Підключаємо WebSocket для отримання замовлень у реальному часі
        if !savedCookie.isEmpty {
            networkManager.connectWebSocket(cookie: savedCookie)
        }
    }
    
    /// Обробка системних подій від сервера
    private func handleWSEvent(_ event: WSEvent) {
        switch event {
        case .authError:
            // Якщо сервер каже, що сесія застаріла — розлогінюємо кур'єра
            print("ContentView: Помилка авторизації, вихід...")
            savedCookie = ""
            networkManager.disconnectWebSocket()
        default:
            break
        }
    }
}
