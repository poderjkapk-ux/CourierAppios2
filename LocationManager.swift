import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let manager = CLLocationManager()
    
    // Переменные, за изменением которых будет следить интерфейс
    @Published var userLocation: CLLocation?
    @Published var isTracking = false
    
    // Достаем токен авторизации (cookie) из локального хранилища (аналог SharedPreferences)
    @AppStorage("cookie") var savedCookie: String = ""
    
    override init() {
        super.init()
        manager.delegate = self
        // Настраиваем высокую точность, как Priority.PRIORITY_HIGH_ACCURACY
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // Разрешаем работу в фоновом режиме (когда приложение свернуто)
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        // Обновлять не чаще чем каждые 10 метров (аналог setMinUpdateIntervalMillis)
        manager.distanceFilter = 10
    }
    
    // Запрос разрешений у пользователя
    func requestPermissions() {
        // Запрашиваем "Всегда", так как курьер должен отслеживаться в фоне, даже с выключенным экраном
        manager.requestAlwaysAuthorization()
    }
    
    // Старт службы геолокации
    func startTracking() {
        manager.startUpdatingLocation()
        isTracking = true
    }
    
    // Остановка службы геолокации
    func stopTracking() {
        manager.stopUpdatingLocation()
        isTracking = false
    }
    
    // Этот метод вызывается системой, когда приходят новые координаты от спутника (аналог onLocationResult)
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // --- ЗАЩИТА ОТ РЕБ (GPS SPOOFING) ---
        // Одесская область примерно в этих координатах
        let isRealLocation = (lat > 45.0 && lat < 48.0) && (lon > 29.0 && lon < 32.0)
        
        if !isRealLocation {
            print("РЕБ DETECTED! Фейковая локация проигнорована: \(lat), \(lon)")
            return // Перерываем отправку, ждем следующего обновления GPS
        }
        // -------------------------------------
        
        self.userLocation = location
        
        // Передаем данные для отправки на сервер
        sendLocationToServer(lat: lat, lon: lon)
    }
    
    // Обработка ошибок
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Ошибка получения локации: \(error.localizedDescription)")
    }
    
    private func sendLocationToServer(lat: Double, lon: Double) {
        // Если нет сохраненного токена, отбиваем отправку
        guard !savedCookie.isEmpty else {
            print("LocationManager: Помилка - Немає збереженого токену (Cookie)")
            return
        }
        
        // 1. БЫСТРАЯ ОТПРАВКА: через WebSocket (для мгновенного отображения)
        NetworkManager.shared.sendLocationWS(lat: lat, lon: lon)
        print("Отправлено GPS через WS: \(lat), \(lon)")
        
        // 2. НАДЕЖНАЯ ОТПРАВКА: через обычный REST API POST-запрос
        // Task - аналог CoroutineScope(Dispatchers.IO).launch в Kotlin
        Task {
            do {
                let response = try await NetworkManager.shared.sendLocation(cookie: savedCookie, lat: lat, lon: lon)
                print("Отправлено GPS через REST API: \(lat), \(lon) (Status: \(response.status))")
            } catch {
                print("Ошибка отправки GPS через REST API: \(error.localizedDescription)")
            }
        }
    }
}
