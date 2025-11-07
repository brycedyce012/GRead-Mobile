import SwiftUI
import Foundation
internal import Combine

// MARK: - Auth Manager with JWT
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    var jwtToken: String?
    
    private init() {
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
            
            if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                // Try to parse error message
                if let errorResponse = try? JSONDecoder().decode(JWTErrorResponse.self, from: data) {
                    print("JWT Error: \(errorResponse.message ?? "Unknown error")")
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
            let user: User = try await APIManager.shared.request(
                endpoint: "/members/me",
                authenticated: true
            )
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                saveAuthState()
            }
        } catch let error as AuthError {
            throw error
        } catch {
            print("Login error: \(error)")
            throw AuthError.networkError
        }
    }
    
    func logout() {
        jwtToken = nil
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "jwtToken")
        UserDefaults.standard.removeObject(forKey: "userId")
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
    
    private func fetchCurrentUser() async throws {
        let user: User = try await APIManager.shared.request(
            endpoint: "/members/me",
            authenticated: true
        )
        await MainActor.run {
            self.currentUser = user
        }
    }
}
