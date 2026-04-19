import SwiftUI
import PhotosUI

struct RegistrationView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var password = ""
    @State private var verificationToken: String? = nil
    @State private var isPhoneVerified = false
    @State private var phoneFromServer = ""
    
    // Стан для вибору фото
    @State private var documentItem: PhotosPickerItem?
    @State private var documentImage: UIImage?
    
    @State private var selfieItem: PhotosPickerItem?
    @State private var selfieImage: UIImage?
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .center, spacing: 24) {
                        
                        // MARK: - Індикатори кроків
                        HStack(alignment: .center, spacing: 0) {
                            StepCircle(step: "1", isCompleted: isPhoneVerified, isActive: !isPhoneVerified)
                            Rectangle()
                                .fill(isPhoneVerified ? AppColors.secondary : Color.gray.opacity(0.3))
                                .frame(width: 40, height: 2)
                            StepCircle(step: "2", isCompleted: false, isActive: isPhoneVerified)
                        }
                        .padding(.top, 16)
                        
                        if !isPhoneVerified {
                            // MARK: - КРОК 1: Підтвердження Telegram
                            VStack(spacing: 16) {
                                Image(systemName: "phone.bubble.left.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppColors.primary)
                                
                                Text("Підтвердження номеру")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                
                                Text("Для безпеки нам потрібно підтвердити ваш номер через нашого Telegram бота.")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button(action: startTelegramVerification) {
                                    HStack {
                                        if isLoading {
                                            // ВИПРАВЛЕНО ТУТ:
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("Відкрити Telegram")
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.primary)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                }
                                .disabled(isLoading)
                                .padding(.top, 16)
                            }
                            .padding(24)
                            .background(Color.white)
                            .cornerRadius(24)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                            
                        } else {
                            // MARK: - КРОК 2: Дані та Документи
                            VStack(spacing: 20) {
                                Text("Номер підтверджено: \(phoneFromServer)")
                                    .font(.headline)
                                    .foregroundColor(AppColors.secondary)
                                    .padding(.bottom, 8)
                                
                                // Поля вводу
                                CustomTextField(placeholder: "Ваше Ім'я", text: $name)
                                CustomSecureField(placeholder: "Придумайте пароль", text: $password)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Документи")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primary)
                                    Text("Завантажте чіткі фото для перевірки")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                                
                                // Вибір фотографій
                                HStack(spacing: 16) {
                                    PhotoPickerBox(title: "Фото ID/Паспорт", icon: "doc.text.viewfinder", item: $documentItem, image: $documentImage)
                                    PhotoPickerBox(title: "Ваше Селфі", icon: "person.crop.square", item: $selfieItem, image: $selfieImage)
                                }
                                
                                Button(action: submitRegistration) {
                                    HStack {
                                        if isLoading {
                                            // ВИПРАВЛЕНО ТУТ:
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("Відправити заявку")
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isFormValid ? AppColors.primary : AppColors.textSecondary.opacity(0.5))
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                }
                                .disabled(!isFormValid || isLoading)
                                .padding(.top, 16)
                            }
                        }
                        
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.error.opacity(0.1))
                            .foregroundColor(AppColors.error)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Стати кур'єром")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Валідація
    private var isFormValid: Bool {
        return !name.isEmpty && !password.isEmpty && documentImage != nil && selfieImage != nil
    }
    
    // MARK: - Логіка Telegram
    private func startTelegramVerification() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await NetworkManager.shared.initVerification()
                verificationToken = response.token
                
                var tgLink = response.link
                // Конвертуємо посилання t.me у tg://resolve для обходу браузера (як в Android)
                if tgLink.contains("t.me/") {
                    let path = tgLink.components(separatedBy: "t.me/").last ?? ""
                    let parts = path.split(separator: "?")
                    let botUsername = parts[0].replacingOccurrences(of: "/", with: "")
                    let startParam = parts.count > 1 ? "&\(parts[1])" : ""
                    tgLink = "tg://resolve?domain=\(botUsername)\(startParam)"
                }
                
                // Відкриваємо Telegram
                if let url = URL(string: tgLink), UIApplication.shared.canOpenURL(url) {
                    await UIApplication.shared.open(url)
                    pollVerificationStatus() // Запускаємо перевірку в фоні
                } else {
                    errorMessage = "Не вдалося відкрити Telegram. Перевірте, чи встановлено додаток."
                    isLoading = false
                }
                
            } catch {
                errorMessage = "Помилка сервера. Спробуйте пізніше."
                isLoading = false
            }
        }
    }
    
    // Фонове опитування сервера (Polling)
    private func pollVerificationStatus() {
        Task {
            var attempts = 0
            let maxAttempts = 100 // Близько 5 хвилин
            
            while !isPhoneVerified && attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // Затримка 3 секунди
                attempts += 1
                
                guard let token = verificationToken else { break }
                
                do {
                    let check = try await NetworkManager.shared.checkVerification(token: token)
                    if check.status == "verified" {
                        await MainActor.run {
                            isPhoneVerified = true
                            phoneFromServer = check.phone ?? ""
                            isLoading = false
                        }
                        break
                    }
                } catch {
                    print("Polling error: \(error)") // Ігноруємо помилки мережі під час опитування
                }
            }
            
            if !isPhoneVerified && attempts >= maxAttempts {
                await MainActor.run {
                    errorMessage = "Час очікування вийшов. Спробуйте ще раз."
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Відправка реєстрації
    private func submitRegistration() {
        guard let docImg = documentImage, let selImg = selfieImage, let token = verificationToken else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let success = try await NetworkManager.shared.registerCourier(
                    name: name,
                    pass: password,
                    token: token,
                    docImage: docImg,
                    selfieImage: selImg
                )
                
                if success {
                    // Успішна реєстрація - повертаємось на екран входу
                    presentationMode.wrappedValue.dismiss()
                } else {
                    errorMessage = "Помилка відправки даних на сервер"
                }
            } catch {
                errorMessage = "Помилка мережі при відправці"
            }
            isLoading = false
        }
    }
}

// MARK: - Допоміжні UI Компоненти
struct StepCircle: View {
    let step: String
    let isCompleted: Bool
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? AppColors.secondary : (isActive ? AppColors.primary : Color.gray.opacity(0.3)))
                .frame(width: 32, height: 32)
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
            } else {
                Text(step)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
        }
    }
}

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField(placeholder, text: $text)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        SecureField(placeholder, text: $text)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
    }
}

// Компонент вибору фото через PhotosUI
struct PhotoPickerBox: View {
    let title: String
    let icon: String
    @Binding var item: PhotosPickerItem?
    @Binding var image: UIImage?
    
    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            VStack(spacing: 8) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(image != nil ? AppColors.secondary : AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(image != nil ? AppColors.secondary.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(image != nil ? AppColors.secondary : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .onChange(of: item) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    self.image = uiImage
                }
            }
        }
    }
}

// MARK: - РОЗШИРЕННЯ NetworkManager ДЛЯ РЕЄСТРАЦІЇ

extension NetworkManager {
    struct InitVerificationResponse: Codable {
        let token: String
        let link: String
    }
    
    struct CheckVerificationResponse: Codable {
        let status: String
        let phone: String?
    }
    
    func initVerification() async throws -> InitVerificationResponse {
        guard let url = URL(string: "https://restify.site/api/courier/init_verification") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Пусте тіло, як в Kotlin EmptyRequest()
        request.httpBody = try JSONEncoder().encode(EmptyRequest())
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(InitVerificationResponse.self, from: data)
    }
    
    func checkVerification(token: String) async throws -> CheckVerificationResponse {
        guard let url = URL(string: "https://restify.site/api/courier/check_verification?token=\(token)") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(CheckVerificationResponse.self, from: data)
    }
    
    // Відправка Multipart/Form-Data (Аналог Retrofit MultipartBody.Part)
    func registerCourier(name: String, pass: String, token: String, docImage: UIImage, selfieImage: UIImage) async throws -> Bool {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "https://restify.site/api/courier/register") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let textFields = ["name": name, "password": pass, "token": token]
        
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        if let docData = docImage.jpegData(compressionQuality: 0.7) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"document_photo\"; filename=\"doc.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(docData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let selfieData = selfieImage.jpegData(compressionQuality: 0.7) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"selfie_photo\"; filename=\"selfie.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(selfieData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return (200...299).contains(httpResponse.statusCode)
        }
        return false
    }
}
