import SwiftUI

struct LoginView: View {
    @State private var phone = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Аналог SharedPreferences: сохраняем куки для автоматического входа
    @AppStorage("cookie") var savedCookie: String = ""
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            // Блок логотипа (аналог restify_logo из Android)
            VStack(spacing: 12) {
                Image(systemName: "box.truck.fill") // Можно заменить на ваш ассет restify_logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("Restify")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Доставка для кур'єрів")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 30)
            
            // Поля ввода (аналог OutlinedTextField из Compose)
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "phone")
                        .foregroundColor(.gray)
                    TextField("Номер телефону", text: $phone)
                        .keyboardType(.phonePad)
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                    SecureField("Пароль", text: $password)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Вывод ошибок
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Кнопка входа
            Button(action: {
                Task {
                    await performLogin()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Увійти")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(phone.isEmpty || password.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading || phone.isEmpty || password.isEmpty)
            .padding(.horizontal)
            
            Button("Забули пароль?") {
                // В будущем здесь вызовем resetCourierPassword из NetworkManager
            }
            .font(.footnote)
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("v1.0.0")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    @MainActor
    private func performLogin() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Вызываем метод авторизации из нашего обновленного NetworkManager
            if let cookie = try await NetworkManager.shared.login(phone: phone, password: password) {
                // Очищаем куки от лишних пробелов, если они есть
                let cleanCookie = cookie.trimmingCharacters(in: .whitespaces)
                
                self.savedCookie = cleanCookie
                self.isLoading = false
                print("Вход выполнен, куки сохранены")
            } else {
                errorMessage = "Помилка входу. Перевірте номер та пароль."
                isLoading = false
            }
        } catch {
            errorMessage = "Помилка з'єднання: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
