import SwiftUI

struct ActivityFeedView: View {
    @State private var activities: [Activity] = []
    @State private var isLoading = false
    @State private var showingNewPost = false
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var hasMorePages = true
    @State private var selectedActivity: Activity?
    @State private var showingUserProfile = false
    @State private var selectedUserId: Int?
    
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
                    List {
                        ForEach(activities) { activity in
                            ActivityRowView(
                                activity: activity,
                                onUserTap: { userId in
                                    selectedUserId = userId
                                    showingUserProfile = true
                                },
                                onReport: {
                                    selectedActivity = activity
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if activity.userId == AuthManager.shared.currentUser?.id {
                                    Button(role: .destructive) {
                                        deleteActivity(activity)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            
                            if activity.id == activities.last?.id && hasMorePages && !isLoading {
                                ProgressView()
                                    .onAppear {
                                        Task {
                                            await loadMoreActivities()
                                        }
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        page = 1
                        hasMorePages = true
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
                        page = 1
                        hasMorePages = true
                        await loadActivities()
                    }
                })
            }
            .sheet(isPresented: $showingUserProfile) {
                if let userId = selectedUserId {
                    UserProfileView(userId: userId)
                }
            }
            .alert("Report Activity", isPresented: Binding(
                get: { selectedActivity != nil },
                set: { if !$0 { selectedActivity = nil } }
            )) {
                if let activity = selectedActivity {
                    Button("Spam", role: .destructive) {
                        reportActivity(activity, reason: "spam")
                    }
                    Button("Inappropriate Content", role: .destructive) {
                        reportActivity(activity, reason: "inappropriate")
                    }
                    Button("Harassment", role: .destructive) {
                        reportActivity(activity, reason: "harassment")
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: {
                Text("Why are you reporting this post?")
            }
            .task {
                if activities.isEmpty {
                    await loadActivities()
                }
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
            // Request with populate_extras to get user info
            let activityResponse: ActivityResponse = try await APIManager.shared.request(
                endpoint: "/activity?per_page=20&page=\(page)&display_comments=false"
            )
            let response = activityResponse.activities

            print("📦 Loaded \(response.count) activities")
            if let first = response.first {
                print("🔍 First activity sample:")
                print("   ID: \(first.id)")
                print("   userId: \(first.userId ?? -1)")
                print("   displayName: \(first.displayName ?? "nil")")
                print("   userLogin: \(first.userLogin ?? "nil")")
                print("   userFullname: \(first.userFullname ?? "nil")")
                print("   bestUserName: \(first.bestUserName)")
            }
            
            await MainActor.run {
                if page == 1 {
                    activities = response
                } else {
                    activities.append(contentsOf: response)
                }
                hasMorePages = response.count >= 20
                isLoading = false
            }
        } catch APIError.emptyResponse {
            await MainActor.run {
                if page == 1 {
                    activities = []
                }
                hasMorePages = false
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load activities: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func loadMoreActivities() async {
        guard !isLoading && hasMorePages else { return }
        page += 1
        await loadActivities()
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
    
    private func reportActivity(_ activity: Activity, reason: String) {
        selectedActivity = nil
        
        Task {
            do {
                var userId: Int?
                
                if let uid = activity.userId {
                    userId = uid
                } else if let itemId = activity.itemId {
                    userId = itemId
                } else if let secondaryItemId = activity.secondaryItemId {
                    userId = secondaryItemId
                }
                
                guard let finalUserId = userId else {
                    await MainActor.run {
                        errorMessage = "Cannot report: User ID not found"
                    }
                    return
                }
                
                let body: [String: Any] = [
                    "user_id": finalUserId,
                    "reason": reason
                ]
                
                struct ReportResponse: Codable {
                    let success: Bool
                    let message: String?
                }
                
                let response: ReportResponse = try await APIManager.shared.customRequest(
                    endpoint: "/user/report",
                    method: "POST",
                    body: body
                )
                
                await MainActor.run {
                    if response.success {
                        errorMessage = "Report submitted successfully"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if errorMessage == "Report submitted successfully" {
                                errorMessage = nil
                            }
                        }
                    } else {
                        errorMessage = response.message ?? "Failed to submit report"
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to report: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct ActivityRowView: View {
    let activity: Activity
    let onUserTap: (Int) -> Void
    let onReport: () -> Void
    @State private var isLiked = false
    @State private var showingComments = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    }
                    .onTapGesture {
                        if let userId = activity.userId {
                            onUserTap(userId)
                        }
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Button(action: {
                        if let userId = activity.userId {
                            onUserTap(userId)
                        }
                    }) {
                        Text(activity.bestUserName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
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
                
                Menu {
                    Button(role: .destructive) {
                        onReport()
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
            
            if let content = activity.content, !content.isEmpty {
                Text(content.stripHTML())
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            
            HStack(spacing: 20) {
                Button {
                    toggleLike()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                        Text("Like")
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                }
                
                Button {
                    showingComments = true
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
        .sheet(isPresented: $showingComments) {
            CommentView(activity: activity)
        }
    }
    
    private func toggleLike() {
        Task {
            do {
                if isLiked {
                    await MainActor.run {
                        isLiked = false
                    }
                } else {
                    let body: [String: Any] = [:]
                    let _: AnyCodable = try await APIManager.shared.request(
                        endpoint: "/activity/\(activity.id)/favorite",
                        method: "POST",
                        body: body
                    )
                    await MainActor.run {
                        isLiked = true
                    }
                }
            } catch {
                print("Failed to toggle like: \(error)")
            }
        }
    }
}

struct CommentView: View {
    @Environment(\.dismiss) var dismiss
    let activity: Activity
    @State private var commentText = ""
    @State private var isPosting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let content = activity.content {
                            Text(content.stripHTML())
                                .padding()
                        }
                        
                        Divider()
                        
                        Text("Comments")
                            .font(.headline)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $commentText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                        .lineLimit(1...5)
                    
                    Button {
                        postComment()
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(commentText.isEmpty ? .gray : .blue)
                        }
                    }
                    .disabled(commentText.isEmpty || isPosting)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func postComment() {
        isPosting = true
        Task {
            do {
                let body: [String: Any] = [
                    "content": commentText,
                    "parent": activity.id
                ]
                
                let _: Activity = try await APIManager.shared.request(
                    endpoint: "/activity",
                    method: "POST",
                    body: body
                )
                
                await MainActor.run {
                    commentText = ""
                    isPosting = false
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                }
            }
        }
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
                
                let _: AnyCodable = try await APIManager.shared.request(
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

struct UserProfileView: View {
    let userId: Int
    @Environment(\.dismiss) var dismiss
    @State private var user: User?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if let user = user {
                    ScrollView {
                        VStack(spacing: 20) {
                            VStack(spacing: 12) {
                                AsyncImage(url: URL(string: user.avatarUrls?.full ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                
                                Text(user.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if let username = user.userLogin {
                                    Text("@\(username)")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.top, 20)
                            
                            Divider()
                            
                            Spacer()
                        }
                        .padding()
                    }
                } else {
                    Text("User not found")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadUser()
            }
        }
    }
    
    private func loadUser() async {
        do {
            let loadedUser: User = try await APIManager.shared.request(
                endpoint: "/members/\(userId)"
            )
            await MainActor.run {
                user = loadedUser
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
