import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var libraryItems: [LibraryItem] = []
    @State private var isLoading = false
    @State private var showAddBook = false
    @State private var searchText = ""
    @State private var selectedFilter: String = "all"

    let filterOptions = ["all", "reading", "completed", "paused"]

    var filteredItems: [LibraryItem] {
        let filtered = selectedFilter == "all"
            ? libraryItems
            : libraryItems.filter { $0.status == selectedFilter }

        if searchText.isEmpty {
            return filtered
        }
        return filtered.filter { item in
            item.book?.title.localizedCaseInsensitiveContains(searchText) ?? false ||
            item.book?.author?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if libraryItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("Your Library is Empty")
                            .font(.headline)
                            .foregroundColor(.gray)

                        Text("Add books to get started tracking your reading")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button(action: { showAddBook = true }) {
                            Label("Add First Book", systemImage: "plus.circle.fill")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding()
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    VStack {
                        // Search and Filter
                        VStack(spacing: 12) {
                            SearchBar(text: $searchText)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filterOptions, id: \.self) { option in
                                        FilterButton(
                                            label: option.capitalized,
                                            isSelected: selectedFilter == option,
                                            action: { selectedFilter = option }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))

                        // Library Items List
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(filteredItems) { item in
                                    LibraryItemCard(libraryItem: item, onDelete: {
                                        deleteBook(item)
                                    }, onProgressUpdate: { newPage in
                                        updateProgress(item: item, currentPage: newPage)
                                    })
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddBook = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookSheet(isPresented: $showAddBook, onBookAdded: {
                    loadLibrary()
                })
                .environmentObject(authManager)
            }
            .onAppear {
                loadLibrary()
            }
            .refreshable {
                await loadLibraryAsync()
            }
        }
    }

    private func loadLibrary() {
        isLoading = true
        Task {
            await loadLibraryAsync()
        }
    }

    private func loadLibraryAsync() async {
        do {
            libraryItems = try await APIManager.shared.customRequest(
                endpoint: "/library",
                method: "GET",
                authenticated: true
            )
            isLoading = false
        } catch {
            print("Error loading library: \(error)")
            isLoading = false
        }
    }

    private func deleteBook(_ item: LibraryItem) {
        Task {
            do {
                let _: EmptyResponse = try await APIManager.shared.customRequest(
                    endpoint: "/library/remove?book_id=\(item.bookId)",
                    method: "DELETE",
                    authenticated: true
                )
                libraryItems.removeAll { $0.id == item.id }
            } catch {
                print("Error removing book: \(error)")
            }
        }
    }

    private func updateProgress(item: LibraryItem, currentPage: Int) {
        Task {
            do {
                let body = ["current_page": currentPage]
                let _: EmptyResponse = try await APIManager.shared.customRequest(
                    endpoint: "/library/progress?book_id=\(item.bookId)&current_page=\(currentPage)",
                    method: "POST",
                    body: body,
                    authenticated: true
                )

                if let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
                    libraryItems[index].currentPage = currentPage
                }
            } catch {
                print("Error updating progress: \(error)")
            }
        }
    }
}

// MARK: - Library Item Card
struct LibraryItemCard: View {
    let libraryItem: LibraryItem
    let onDelete: () -> Void
    let onProgressUpdate: (Int) -> Void

    @State private var showProgressEditor = false
    @State private var newPageCount = 0

    var progressPercentage: Double {
        guard let totalPages = libraryItem.book?.totalPages, totalPages > 0 else { return 0 }
        return Double(libraryItem.currentPage) / Double(totalPages) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Book Cover Placeholder
                if let coverUrl = libraryItem.book?.coverUrl, !coverUrl.isEmpty {
                    AsyncImage(url: URL(string: coverUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 60, height: 90)
                    .cornerRadius(4)
                } else {
                    Image(systemName: "book.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                        .frame(width: 60, height: 90)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(libraryItem.book?.title ?? "Unknown Book")
                        .font(.headline)
                        .lineLimit(2)

                    if let author = libraryItem.book?.author {
                        Text(author)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    HStack(spacing: 8) {
                        if let status = libraryItem.status {
                            StatusBadge(status: status)
                        }
                    }

                    Spacer()

                    Text("\(libraryItem.currentPage) / \(libraryItem.book?.totalPages ?? 0) pages")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Menu {
                    Button(action: { showProgressEditor = true }) {
                        Label("Update Progress", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Remove from Library", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }

            // Progress Bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray6))
                    .frame(height: 8)

                Capsule()
                    .fill(Color.blue)
                    .frame(width: CGFloat(progressPercentage) / 100 * 270, height: 8)
            }

            HStack {
                Text("\(Int(progressPercentage))% complete")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Button(action: { showProgressEditor = true }) {
                    Text("Update")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .sheet(isPresented: $showProgressEditor) {
            ProgressEditorSheet(
                isPresented: $showProgressEditor,
                currentPage: libraryItem.currentPage,
                totalPages: libraryItem.book?.totalPages ?? 0,
                onSave: { newPage in
                    onProgressUpdate(newPage)
                    showProgressEditor = false
                }
            )
        }
    }
}

// MARK: - Progress Editor Sheet
struct ProgressEditorSheet: View {
    @Binding var isPresented: Bool
    let currentPage: Int
    let totalPages: Int
    let onSave: (Int) -> Void

    @State private var pageInput = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Progress")
                        .font(.headline)

                    Text("\(currentPage) / \(totalPages) pages")
                        .font(.title3)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Update to page:")
                        .font(.headline)

                    HStack {
                        TextField("Page number", text: $pageInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)

                        Stepper("", value: Binding(
                            get: { Int(pageInput) ?? currentPage },
                            set: { pageInput = String($0) }
                        ), in: currentPage...totalPages)
                    }
                }

                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { Double(Int(pageInput) ?? currentPage) },
                            set: { pageInput = String(Int($0)) }
                        ),
                        in: Double(currentPage)...Double(totalPages)
                    )

                    HStack {
                        Text("\(currentPage)p")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(totalPages)p")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Button(action: {
                    let page = Int(pageInput) ?? currentPage
                    let finalPage = min(max(page, currentPage), totalPages)
                    onSave(finalPage)
                }) {
                    Text("Save Progress")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(pageInput.isEmpty)
            }
            .padding()
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            pageInput = String(currentPage)
        }
    }
}

// MARK: - Add Book Sheet
struct AddBookSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var isPresented: Bool
    let onBookAdded: () -> Void

    @State private var searchQuery = ""
    @State private var searchResults: [Book] = []
    @State private var isSearching = false
    @State private var selectedBook: Book?
    @State private var showConfirmation = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                SearchBar(text: $searchQuery)
                    .padding()

                if isSearching {
                    ProgressView()
                        .frame(maxHeight: .infinity, alignment: .center)
                } else if !searchResults.isEmpty {
                    List(searchResults) { book in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(book.title)
                                .font(.headline)

                            if let author = book.author {
                                Text(author)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }

                            if let description = book.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedBook = book
                            showConfirmation = true
                        }
                    }
                } else if !searchQuery.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("No books found")
                            .font(.headline)
                            .foregroundColor(.gray)

                        Text("Try searching with different keywords")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("Search for books")
                            .font(.headline)
                            .foregroundColor(.gray)

                        Text("Enter a book title or author name")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: searchQuery) { _ in
                if !searchQuery.isEmpty {
                    performSearch()
                } else {
                    searchResults = []
                }
            }
            .alert("Add Book", isPresented: $showConfirmation, actions: {
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    if let book = selectedBook {
                        addBook(book)
                    }
                }
            }, message: {
                if let book = selectedBook {
                    Text("Add '\(book.title)' to your library?")
                }
            })
        }
    }

    private func performSearch() {
        isSearching = true
        Task {
            do {
                searchResults = try await APIManager.shared.customRequest(
                    endpoint: "/books/search?query=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                    method: "GET",
                    authenticated: true
                )
                isSearching = false
            } catch {
                print("Error searching books: \(error)")
                isSearching = false
                searchResults = []
            }
        }
    }

    private func addBook(_ book: Book) {
        Task {
            do {
                let body = ["book_id": book.id]
                let _: EmptyResponse = try await APIManager.shared.customRequest(
                    endpoint: "/library/add?book_id=\(book.id)",
                    method: "POST",
                    body: body,
                    authenticated: true
                )
                onBookAdded()
                isPresented = false
            } catch {
                print("Error adding book: \(error)")
            }
        }
    }
}

// MARK: - Helper Views
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search...", text: $text)
                .textFieldStyle(.roundedBorder)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct FilterButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct StatusBadge: View {
    let status: String

    var statusColor: Color {
        switch status.lowercased() {
        case "reading":
            return .blue
        case "completed":
            return .green
        case "paused":
            return .orange
        default:
            return .gray
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
}

#Preview {
    LibraryView()
        .environmentObject(AuthManager())
}
