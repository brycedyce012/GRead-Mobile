import SwiftUI

struct LandingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showLoginRegister = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Section with Logo
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    VStack(spacing: 12) {
                        Text("Welcome to GRead")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Connect with your community")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Spacer()
                        .frame(height: 20)
                }
                .frame(maxWidth: .infinity)

                // Bottom Section with Buttons
                VStack(spacing: 12) {
                    // Continue as Guest Button
                    Button(action: continueAsGuest) {
                        HStack {
                            Image(systemName: "eyes")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Browse as Guest")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }

                    // Login/Register Button
                    NavigationLink(destination: LoginRegisterView()) {
                        HStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Sign In / Sign Up")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    // Divider
                    HStack {
                        Divider()
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Divider()
                    }
                    .padding(.vertical, 8)

                    // Direct Register Button
                    NavigationLink(destination: LoginRegisterView()) {
                        HStack {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Create New Account")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .navigationBarHidden(true)
        }
    }

    private func continueAsGuest() {
        authManager.enterGuestMode()
    }
}

#Preview {
    LandingView()
        .environmentObject(AuthManager.shared)
}
