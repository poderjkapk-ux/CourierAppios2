import SwiftUI
import UIKit // Додано для виправлення помилки UIApplicationDelegate
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// MARK: - Аналог MyFirebaseMessagingService.kt и инициализации в MainActivity
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Инициализация Firebase
        FirebaseApp.configure()
        
        // Запрос разрешений на Push-уведомления
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if granted {
                print("Разрешение на пуши получено")
            }
        }
        application.registerForRemoteNotifications()
        
        // Назначаем делегат для получения токена
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // Передача APNs токена Apple в Firebase
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // MARK: - Получение FCM Токена (аналог onNewToken в Android)
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("Firebase Registration Token: \(fcmToken)")
        
        // Достаем cookie из AppStorage
        let cookie = UserDefaults.standard.string(forKey: "cookie") ?? ""
        
        // Если курьер авторизован, отправляем токен на бэкенд
        if !cookie.isEmpty {
            Task {
                do {
                    _ = try await NetworkManager.shared.sendFcmToken(cookie: cookie, token: fcmToken)
                    print("FCM токен успешно обновлен на сервере")
                } catch {
                    print("Ошибка отправки FCM токена: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Обработка уведомлений, когда приложение открыто (Foreground)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Показываем уведомление (баннер и звук), даже если курьер сидит в приложении
        completionHandler([[.banner, .badge, .sound]])
    }
    
    // MARK: - Обработка клика по уведомлению
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("Пользователь тапнул на пуш: \(userInfo)")
        
        // Здесь можно добавить логику перехода на конкретный экран (например, на вкладку "Активные")
        completionHandler()
    }
}

// MARK: - Главная точка входа в приложение
@main
struct CourierAppApp: App {
    // Подключаем наш AppDelegate к SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Фиксируем светлую тему для курьерского приложения (опционально)
                .preferredColorScheme(.light)
        }
    }
}
