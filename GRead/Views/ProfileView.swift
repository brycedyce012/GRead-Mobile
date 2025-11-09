//
//  ProfileView.swift
//  GRead
//
//  Created by apple on 11/6/25.
//

import SwiftUI


struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var stats: UserStats?
    @State private var showStatsView = false
    @State private var isLoadingStats = false
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        NavigationView {
            List {
                if let user = authManager.currentUser {
                    Section {
                        HStack {
                            AsyncImage(url: URL(string: user.avatarUrls?.full ?? "")) { image in
                                image.resizable()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                if let username = user.userLogin {
                                    Text("@\(username)")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical)
                    }

                    Section(header: Text("Your Stats")) {
                        if let stats = stats {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    StatRow(label: "Points", value: "\(stats.points)", icon: "star.fill", color: .yellow)
                                    StatRow(label: "Books Completed", value: "\(stats.booksCompleted)", icon: "checkmark.circle.fill", color: .green)
                                    StatRow(label: "Pages Read", value: "\(stats.pagesRead)", icon: "book.fill", color: .blue)
                                    StatRow(label: "Books Added", value: "\(stats.booksAdded)", icon: "plus.circle.fill", color: .purple)
                                }
                            }
                        } else if isLoadingStats {
                            ProgressView()
                        } else {
                            Text("No stats available")
                                .foregroundColor(.gray)
                        }
                    }

                    Section(header: Text("Customization")) {
                        NavigationLink(destination: ThemeSelectionView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Active Theme")
                                    Text(themeManager.currentTheme.name)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    Section(header: Text("Settings")) {
                        NavigationLink(destination: BlockedUsersView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.red)
                                Text("Blocked Users")
                            }
                        }
                    }

                    Section(header: Text("Support")) {
                        Link(destination: URL(string: "mailto:admin@gread.fun?subject=Contact%20Request")!) {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text("Contact Developers")
                            }
                        }

                        Link(destination: URL(string: "mailto:admin@gread.fun?subject=Request%20Data%20Deletion")!) {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.orange)
                                Text("Request Data Deletion")
                            }
                        }
                    }

                    Section(header: Text("Legal")) {
                        Link("Privacy Policy", destination: URL(string: "https://gread.fun/privacy-policy")!)
                        Link("Terms of Service", destination: URL(string: "https://gread.fun/tos")!)
                    }
                }

                Section {
                    Button(action: { authManager.logout() }) {
                        Text("Logout")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
            .task {
                loadUserStats()
            }
        }
    }

    private func loadUserStats() {
        guard let userId = authManager.currentUser?.id else { return }

        Task {
            isLoadingStats = true
            do {
                stats = try await APIManager.shared.getUserStats(userId: userId)
            } catch {
                print("Failed to load user stats: \(error)")
            }
            isLoadingStats = false
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
    }
}
