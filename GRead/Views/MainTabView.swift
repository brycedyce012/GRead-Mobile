//
//  MainTabView.swift
//  GRead
//
//  Created by apple on 11/6/25.
//

import SwiftUI


struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingProfile = false

    var body: some View {
        ZStack {
            TabView {
                ActivityFeedView()
                    .environmentObject(authManager)
                    .tabItem {
                        Label("Activity", systemImage: "flame.fill")
                    }

                LibraryView()
                    .environmentObject(authManager)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical.fill")
                    }

                NotificationsView()
                    .tabItem {
                        Label("Notifications", systemImage: "bell.fill")
                    }

                if authManager.isAuthenticated {
                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                } else {
                    GuestProfileView()
                        .environmentObject(authManager)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                }
            }

            // Login prompt overlay for guest users trying to post
            if authManager.isGuestMode {
                VStack {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Sign in to post and interact")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding()

                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
        }
    }
}
