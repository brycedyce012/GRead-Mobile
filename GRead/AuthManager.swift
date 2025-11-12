import SwiftUI
import Foundation
import Combine

// MARK: - Auth Manager with JWT
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isGuestMode = false
    var jwtToken: String?

    init() {
        loadAuthState()
    }
    
    func login(username: String, password: String) async throws {
        // JWT Authentication endpoint
        let url = URL(string: "https://gread.fun/wp-json/jwt-auth/v1/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "username": username,
            "password": password
        ]
        
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("JWT Response: \(responseString)")
            }

            // First, check if response is an error response (has a code field)
            if let errorResponse = try? JSONDecoder().decode(JWTErrorResponse.self, from: data),
               errorResponse.code != nil {
                print("JWT Error detected: \(errorResponse.message ?? "Unknown error")")
                // Show user-friendly message for all registration/account issues
                throw AuthError.registrationFailed("If you are a new user and your username is unique, check your email and verify your account.")
            }

            if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                // Try to parse error message from server
                if let errorResponse = try? JSONDecoder().decode(JWTErrorResponse.self, from: data),
                   let message = errorResponse.message {
                    print("JWT Error: \(message)")
                    throw AuthError.registrationFailed("If you are a new user and your username is unique, check your email and verify your account.")
                }
                throw AuthError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("JWT Auth failed with status: \(httpResponse.statusCode)")
                throw AuthError.httpError(httpResponse.statusCode)
            }

            // Parse JWT response
            let jwtResponse = try JSONDecoder().decode(JWTResponse.self, from: data)
            
            // Store JWT token
            self.jwtToken = jwtResponse.token
            
            // Fetch current user from BuddyPress
            try await fetchCurrentUser()
            
            await MainActor.run {
                self.isAuthenticated = true
                self.isGuestMode = false
                saveAuthState()
            }
        } catch let error as AuthError {
            throw error
        } catch {
            print("Login error: \(error)")
            throw AuthError.networkError
        }
    }
    
    func register(username: String, email: String, password: String) async throws {
        // BuddyPress signup endpoint
        let url = URL(string: "https://gread.fun/wp-json/buddypress/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_login": username,
            "user_email": email,
            "password": password,
            "signup_field_data": [
                [
                    "field_id": 1,
                    "value": username
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Registration Response: \(responseString)")
            }

            if httpResponse.statusCode == 400 || httpResponse.statusCode == 409 {
                // Try to parse error message from response in multiple formats
                var errorMessage: String?

                // Try WordPress error response format
                if let errorResponse = try? JSONDecoder().decode(RegistrationErrorResponse.self, from: data) {
                    errorMessage = errorResponse.message
                }

                // Try parsing as generic dictionary for WordPress error format
                if errorMessage == nil, let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let message = jsonDict["message"] as? String {
                        errorMessage = message
                    } else if let data = jsonDict["data"] as? [String: Any], let message = data["message"] as? String {
                        errorMessage = message
                    } else if let errors = jsonDict["errors"] as? [String: Any], let errorDetail = errors.first?.value as? [String: Any], let message = errorDetail["message"] as? String {
                        errorMessage = message
                    }
                }

                if let errorMessage = errorMessage {
                    let lowercasedError = errorMessage.lowercased()
                    
                    if lowercasedError.contains("email is already registered") || lowercasedError.contains("email address is already in use") || lowercasedError.contains("Sorry, that email address is already used!") {
                        throw AuthError.registrationFailed("This email address is already registered.")
                    }
                    
                    if lowercasedError.contains("sorry, that username already exists") || lowercasedError.contains("username is already in use") {
                        throw AuthError.registrationFailed("This username is already taken. Please choose another.")
                    }
                }
                throw AuthError.registrationFailed("Registration failed. Please check your information.")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("Registration failed with status: \(httpResponse.statusCode)")
                throw AuthError.registrationFailed("Registration failed. Please try again.")
            }

            // After successful registration, try to auto-login
            // If account needs activation, this will throw an error which we'll catch
            do {
                try await login(username: username, password: password)
            } catch let error as AuthError {
                // Check if the error is about account not being activated
                if case .unauthorized = error {
                    // Account created but needs email activation
                    throw AuthError.registrationFailed("Account created! Please check your email to activate your account before logging in.")
                }
                throw error
            }
        } catch let error as AuthError {
            throw error
        } catch {
            print("Registration error: \(error)")
            throw AuthError.networkError
        }
    }

    func enterGuestMode() {
        isGuestMode = true
        isAuthenticated = false
    }

    func logout() {
        jwtToken = nil
        currentUser = nil
        isAuthenticated = false
        isGuestMode = false
        UserDefaults.standard.removeObject(forKey: "jwtToken")
        UserDefaults.standard.removeObject(forKey: "userId")
    }
    
    func fetchCurrentUser() async throws {
        let user: User = try await APIManager.shared.request(
            endpoint: "/members/me",
            authenticated: true
        )
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    private func saveAuthState() {
        if let token = jwtToken {
            UserDefaults.standard.set(token, forKey: "jwtToken")
        }
        if let userId = currentUser?.id {
            UserDefaults.standard.set(userId, forKey: "userId")
        }
    }
    
    private func loadAuthState() {
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            return
        }
        
        self.jwtToken = token
        self.isAuthenticated = true
        
        Task {
            do {
                try await fetchCurrentUser()
            } catch {
                // Token might be expired, logout
                await MainActor.run {
                    logout()
                }
            }
        }
    }
}
