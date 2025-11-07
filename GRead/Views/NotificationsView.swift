//
//  NotificationsView.swift
//  GRead
//
//  Created by apple on 11/6/25.
//

import SwiftUI
import Foundation


struct NotificationsView: View {
    @State private var notifications: [Notification] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            SwiftUI.Group {
                if isLoading && notifications.isEmpty {
                    ProgressView()
                } else if notifications.isEmpty {
                    Text("No notifications")
                        .foregroundColor(.gray)
                } else {
                    List(notifications) { notification in
                        NotificationRowView(notification: notification)
                    }
                    .refreshable {
                        await loadNotifications()
                    }
                }
            }
            .navigationTitle("Notifications")
            .task {
                await loadNotifications()
            }
        }
    }
    
    private func loadNotifications() async {
        isLoading = true
        do {
            let response: [Notification] = try await APIManager.shared.request(
                endpoint: "/notifications?per_page=20"
            )
            await MainActor.run {
                notifications = response
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct NotificationRowView: View {
    let notification: Notification
    
    var body: some View {
        HStack {
            Circle()
                .fill(notification.isNew ?? false ? Color.blue : Color.clear)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.componentAction ?? "Notification")
                    .font(.headline)
                
                Text(notification.componentName ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if let date = notification.dateNotified {
                Text(date.toRelativeTime())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .opacity(notification.isNew ?? false ? 1 : 0.6)
    }
}
