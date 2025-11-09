import SwiftUI

struct ActivityFeedView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var activities: [Activity] = []
    @State private var organizedActivities: [Activity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var hasMorePages = true
    @State private var selectedActivity: Activity?
    @State private var showingLoginPrompt = false

    // Sheet state - only one sheet can be open at a time
    enum SheetType: Identifiable {
        case newPost
        case userProfile(userId: Int)
        case moderation(userId: Int, userName: String)
        case comments(activity: Activity)

        var id: String {
            switch self {
            case .newPost: return "newPost"
            case .userProfile: return "userProfile"
            case .moderation: return "moderation"
            case .comments: return "comments"
            }
        }
    }
    @State private var activeSheet: SheetType?
    
    var body: some View {
        ZStack {
            NavigationView {
                Group {
                    // Content
                    if isLoading && organizedActivities.isEmpty {
                        ProgressView("Loading activities...")
                    } else if organizedActivities.isEmpty {
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
                            // Only show top-level activities (those without a parent)
                            ForEach(organizedActivities) { activity in
                                ThreadedActivityView(
                                    activity: activity,
                                    onUserTap: { userId in
                                        activeSheet = .userProfile(userId: userId)
                                    },
                                    onCommentsTap: {
                                        activeSheet = .comments(activity: activity)
                                    },
                                    onReport: {
                                        selectedActivity = activity
                                    },
                                    onDelete: { activityToDelete in
                                        deleteActivity(activityToDelete)
                                    }
                                )

                                if activity.id == organizedActivities.last?.id && hasMorePages && !isLoading {
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
                            if authManager.isGuestMode {
                                showingLoginPrompt = true
                            } else {
                                activeSheet = .newPost
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
                .alert("Sign In Required", isPresented: $showingLoginPrompt) {
                    Button("Sign In") {
                        // Navigate to login
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("You need to sign in to create posts. Please sign in or create an account.")
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
                        Button("Cancel", role: .cancel) {
                            selectedActivity = nil
                        }
                    }
                } message: {
                    Text("Why are you reporting this post?")
                }
                .task {
                    if organizedActivities.isEmpty {
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
            .id(1)  // Stable ID to prevent NavigationView from rebuilding when sheet state changes
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newPost:
                NewActivityView(onPost: {
                    Task {
                        page = 1
                        hasMorePages = true
                        await loadActivities()
                    }
                })
            case .userProfile(let userId):
                UserProfileView(
                    userId: userId,
                    onModerationTap: { userName in
                        activeSheet = .moderation(userId: userId, userName: userName)
                    }
                )
            case .moderation(let userId, let userName):
                ModerationView(userId: userId, userName: userName)
            case .comments(let activity):
                CommentView(
                    activity: activity,
                    onPost: {
                        Task {
                            page = 1
                            hasMorePages = true
                            await loadActivities()
                        }
                    }
                )
            }
        }
    }
    
    private func loadActivities() async {
        isLoading = true
        errorMessage = nil

        do {
            // Request activity feed with user info and comments
            let activityResponse: ActivityResponse = try await APIManager.shared.request(
                endpoint: "/activity?per_page=20&page=\(page)&display_comments=true",
                authenticated: false
            )
            let response = activityResponse.activities

            print("=== ACTIVITY RESPONSE DEBUG ===")
            print("Total from response: \(activityResponse.total ?? -1)")
            print("Has more items: \(activityResponse.hasMoreItems ?? false)")
            print("Activities array count: \(response.count)")

            // Activity feed loaded successfully
            print("📦 Loaded \(response.count) activities")
            
            await MainActor.run {
                if page == 1 {
                    activities = response
                } else {
                    activities.append(contentsOf: response)
                }
                // Organize flat list into hierarchy
                organizedActivities = organizeActivitiesIntoThreads(activities)

                hasMorePages = response.count >= 20
                isLoading = false
            }
        } catch APIError.emptyResponse {
            await MainActor.run {
                if page == 1 {
                    activities = []
                    organizedActivities = []
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

    private func organizeActivitiesIntoThreads(_ flatActivities: [Activity]) -> [Activity] {
        // Create a dictionary for quick lookup and organize activities
        var activityById: [Int: Activity] = [:]

        // Initialize all activities with empty children
        for activity in flatActivities {
            var mutableActivity = activity
            mutableActivity.children = []
            activityById[activity.id] = mutableActivity
        }

        // Build parent-child relationships based on activity type
        for activity in flatActivities {
            // For activity_comment, the parent ID is in itemId or secondaryItemId
            let parentId: Int?
            if activity.type == "activity_comment" {
                // Comments use itemId/secondaryItemId to reference parent
                parentId = activity.itemId ?? activity.secondaryItemId
            } else {
                // Other types don't have comments in this feed
                parentId = nil
            }

            if let parentId = parentId, parentId > 0, var parent = activityById[parentId] {
                // Add this activity as a child of its parent
                if let organizedChild = activityById[activity.id] {
                    parent.children?.append(organizedChild)
                    activityById[parentId] = parent
                }
            }
        }

        // Return only posts (activity_update) without filtering out other types
        // But organize comments under their parent posts
        return flatActivities.filter { $0.type == "activity_update" }.compactMap { activityById[$0.id] }
    }
}

struct ThreadedActivityView: View {
    let activity: Activity
    let onUserTap: (Int) -> Void
    let onCommentsTap: () -> Void
    let onReport: () -> Void
    let onDelete: (Activity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main post
            ActivityRowView(
                activity: activity,
                onUserTap: onUserTap,
                onCommentsTap: onCommentsTap,
                onReport: onReport,
                indentLevel: 0
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if activity.userId == AuthManager.shared.currentUser?.id {
                    Button(role: .destructive) {
                        onDelete(activity)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Comments (children) with indentation
            if let children = activity.children, !children.isEmpty {
                ForEach(children) { child in
                    CommentThreadView(
                        comment: child,
                        onUserTap: onUserTap,
                        onCommentsTap: onCommentsTap,
                        onReport: onReport,
                        onDelete: onDelete,
                        indentLevel: 1
                    )
                }
            }
        }
    }
}

struct CommentThreadView: View {
    let comment: Activity
    let onUserTap: (Int) -> Void
    let onCommentsTap: () -> Void
    let onReport: () -> Void
    let onDelete: (Activity) -> Void
    let indentLevel: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Indentation
                VStack {
                    if indentLevel > 0 {
                        Divider()
                            .frame(height: 60)
                    }
                }
                .frame(width: CGFloat(indentLevel) * 16)

                // Comment content
                ActivityRowView(
                    activity: comment,
                    onUserTap: onUserTap,
                    onCommentsTap: onCommentsTap,
                    onReport: onReport,
                    indentLevel: indentLevel
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if comment.userId == AuthManager.shared.currentUser?.id {
                        Button(role: .destructive) {
                            onDelete(comment)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            // Nested replies
            if let children = comment.children, !children.isEmpty {
                ForEach(children) { child in
                    CommentThreadView(
                        comment: child,
                        onUserTap: onUserTap,
                        onCommentsTap: onCommentsTap,
                        onReport: onReport,
                        onDelete: onDelete,
                        indentLevel: indentLevel + 1
                    )
                }
            }
        }
    }
}

struct ActivityRowView: View {
    let activity: Activity
    let onUserTap: (Int) -> Void
    let onCommentsTap: () -> Void
    let onReport: () -> Void
    let indentLevel: Int

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
            
            // Only show comment button for top-level posts
            if indentLevel == 0 {
                HStack(spacing: 20) {
                    Button {
                        onCommentsTap()
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
        }
        .padding(.vertical, 8)
    }
}

struct CommentView: View {
    @Environment(\.dismiss) var dismiss
    let activity: Activity
    let onPost: () -> Void
    @State private var commentText = ""
    @State private var isPosting = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Original post
                    if let content = activity.content {
                        Text(content.stripHTML())
                            .font(.body)
                            .fontWeight(.medium)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Divider()

                    // Display existing comments
                    if let children = activity.children, !children.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(children) { comment in
                                CommentItemView(comment: comment)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        Text("No comments yet")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                }
                .padding()
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
                    onPost()
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                }
            }
        }
    }
}

struct CommentItemView: View {
    let comment: Activity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.bestUserName)
                        .font(.caption)
                        .fontWeight(.semibold)

                    if let date = comment.dateRecorded {
                        Text(date.toRelativeTime())
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()
            }

            if let content = comment.content {
                Text(content.stripHTML())
                    .font(.caption)
                    .lineLimit(nil)
            }

            // Recursively show nested replies if any
            if let children = comment.children, !children.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 4)

                    ForEach(children) { child in
                        CommentItemView(comment: child)
                            .padding(.leading, 8)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

struct NewActivityView: View {
    @Environment(\.dismiss) var dismiss
    @State private var content = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    let onPost: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Text("New Post")
                    .font(.headline)
                Spacer()
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
            .padding()

            Divider()

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
    let onModerationTap: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var user: User?
    @State private var stats: UserStats?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Done") {
                    dismiss()
                }
                Spacer()
                Text("Profile")
                    .font(.headline)
                Spacer()
                Color.clear
                    .frame(width: 50)
            }
            .padding()

            Divider()

            // Content
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

                        // Stats Section
                        if let stats = stats {
                            Divider()

                            VStack(spacing: 12) {
                                Text("Statistics")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 12) {
                                    StatCard(
                                        label: "Books Completed",
                                        value: "\(stats.booksCompleted)",
                                        icon: "checkmark.circle.fill",
                                        color: .green
                                    )
                                    StatCard(
                                        label: "Pages Read",
                                        value: "\(stats.pagesRead)",
                                        icon: "book.fill",
                                        color: .blue
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        Divider()

                        // Moderation Actions
                        if authManager.currentUser?.id != userId {
                            Button(action: { onModerationTap(user.name) }) {
                                HStack {
                                    Image(systemName: "exclamationmark.shield.fill")
                                    Text("Moderation Options")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }
                            .padding(.vertical, 8)
                        }

                        Spacer()
                    }
                    .padding()
                }
            } else {
                Text("User not found")
                    .foregroundColor(.gray)
            }
        }
        .task {
            await loadUser()
            await loadStats()
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

    private func loadStats() async {
        do {
            let userStats = try await APIManager.shared.getUserStats(userId: userId)
            await MainActor.run {
                stats = userStats
            }
        } catch {
            print("Failed to load user stats: \(error)")
        }
    }
}
