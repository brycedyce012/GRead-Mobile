//
//  MainTabView.swift
//  GRead
//
//  Created by apple on 11/6/25.
//

import SwiftUI


struct MainTabView: View {
    var body: some View {
        TabView {
            ActivityFeedView()
                .tabItem {
                    Label("Activity", systemImage: "flame.fill")
                }
            
            GroupsView()
                .tabItem {
                    Label("Groups", systemImage: "person.3.fill")
                }
            
            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
            
            NotificationsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}
