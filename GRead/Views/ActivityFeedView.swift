import SwiftUI
struct ActivityFeedView: View {
    @State private var activities: [Activity] = []
    @State private var isLoading = false
    @State private var showingNewPost = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading && activities.isEmpty {
                    ProgressView("Loading activities...")
                } else if activities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No activity yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Be the first to post something!")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    List(activities) { activity in
                        ActivityRowView(activity: activity)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteActivity(activity)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadActivities()
                    }
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewPost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingNewPost) {
                NewActivityView(onPost: {
                    Task {
                        await loadActivities()
                    }
                })
            }
            .task {
                await loadActivities()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func loadActivities() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("📱 Loading activities...")
            let response: ActivityResponse = try await APIManager.shared.request(
                endpoint: "/activity?per_page=20"
            )
            print("✅ Loaded \(response.activities.count) activities")
            await MainActor.run {
                activities = response.activities
                isLoading = false
            }
        } catch let error as APIError {
            print("❌ API Error: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        } catch {
            print("❌ Unknown error: \(error)")
            await MainActor.run {
                errorMessage = "Failed to load activities: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func deleteActivity(_ activity: Activity) {
        Task {
            do {
                let _: EmptyResponse = try await APIManager.shared.request(
                    endpoint: "/activity/\(activity.id)",
                    method: "DELETE"
                )
                await MainActor.run {
                    activities.removeAll { $0.id == activity.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete activity"
                }
            }
        }
    }
}

struct ActivityRowView: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with user info
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let title = activity.displayName, !title.isEmpty {
                        Text(title.stripHTML())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text("User \(activity.userId ?? 0)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 4) {
                        if let type = activity.type {
                            Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        if let date = activity.dateRecorded {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(date.toRelativeTime())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Content
            if let content = activity.content, !content.isEmpty {
                Text(content.stripHTML())
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            
            // Action buttons
            HStack(spacing: 20) {
                Button {
                    // Favorite action
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text("Like")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Button {
                    // Comment action
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("Comment")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

struct NewActivityView: View {
    @Environment(\.dismiss) var dismiss
    @State private var content = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    let onPost: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        postActivity()
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
        }
    }
    
    private func postActivity() {
        isPosting = true
        errorMessage = nil
        
        Task {
            do {
                let body: [String: Any] = [
                    "content": content,
                    "type": "activity_update",
                    "component": "activity"
                ]
                
                let _: Activity = try await APIManager.shared.request(
                    endpoint: "/activity",
                    method: "POST",
                    body: body
                )
                
                await MainActor.run {
                    onPost()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to post: \(error.localizedDescription)"
                    isPosting = false
                }
            }
        }
    }
}
