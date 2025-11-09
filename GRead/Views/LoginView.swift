import Foundation
import UIKit
import SwiftUI
import AuthenticationServices
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 20)

                    // Login Form
                    VStack(spacing: 16) {
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                            
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                TextField("Enter your username", text: $username)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .textContentType(.username)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                if showPassword {
                                    TextField("Enter your password", text: $password)
                                        .textContentType(.password)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .textContentType(.password)
                                }
                                
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error Message
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                    }
                    
                    // Login Button
                    Button(action: login) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Login")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (username.isEmpty || password.isEmpty || isLoading) ?
                            Color.gray.opacity(0.3) : Color.blue
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    // Divider
                    HStack {
                        Color.gray.frame(height: 1)
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Color.gray.frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                    // Sign in with Apple
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleSignInWithApple(result)
                        }
                    )
                    .frame(height: 50)
                    .cornerRadius(10)
                    .padding(.horizontal, 24)
                    .signInWithAppleButtonStyle(.black)

                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
    
    private func login() {
        isLoading = true
        errorMessage = nil

        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        Task {
            do {
                try await authManager.login(username: username, password: password)
            } catch let error as AuthError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Login failed. Please try again."
                    isLoading = false
                }
            }
        }
    }

    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let fullName = appleIDCredential.fullName
                let email = appleIDCredential.email

                // Create username from email or full name
                var appleUsername = ""
                if let email = email {
                    appleUsername = email.split(separator: "@").first.map(String.init) ?? "user_\(userIdentifier)"
                } else if let fullName = fullName {
                    appleUsername = "\(fullName.givenName ?? "")\(fullName.familyName ?? "")".lowercased().filter { $0.isLetter }
                    if appleUsername.isEmpty {
                        appleUsername = "user_\(userIdentifier)"
                    }
                } else {
                    appleUsername = "user_\(userIdentifier)"
                }

                // Use Apple user ID as password for security
                let applePassword = userIdentifier

                // Attempt to register first, if user exists they'll get an error and we'll attempt login
                Task {
                    do {
                        let displayEmail = email ?? "\(appleUsername)@gread.local"
                        try await authManager.register(
                            username: appleUsername,
                            email: displayEmail,
                            password: applePassword
                        )
                    } catch let error as AuthError {
                        // If registration fails (user likely exists), try login
                        if case .registrationFailed = error {
                            do {
                                try await authManager.login(username: appleUsername, password: applePassword)
                            } catch {
                                await MainActor.run {
                                    errorMessage = "Apple Sign In failed. Please try again."
                                    isLoading = false
                                }
                            }
                        } else {
                            await MainActor.run {
                                errorMessage = error.errorDescription
                                isLoading = false
                            }
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = "Apple Sign In failed. Please try again."
                            isLoading = false
                        }
                    }
                }
            }
        case .failure(let error):
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
