//
//  GroupsView.swift
//  GRead
//
//  Created by apple on 11/6/25.
//

import Foundation
import SwiftUI


struct GroupsView: View {
    @State private var groups: [BPGroup] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            BPGroup {
                if isLoading && groups.isEmpty {
                    ProgressView()
                } else if groups.isEmpty {
                    Text("No groups found")
                        .foregroundColor(.gray)
                } else {
                    List(groups) { group in
                        NavigationLink(destination: GroupDetailView(group: group)) {
                            GroupRowView(group: group)
                        }
                    }
                    .refreshable {
                        await loadGroups()
                    }
                }
            }
            .navigationTitle("Groups")
            .task {
                await loadGroups()
            }
        }
    }
    
    private func loadGroups() async {
        isLoading = true
        do {
            let response: [BPGroup] = try await APIManager.shared.request(
                endpoint: "/groups?per_page=20"
            )
            await MainActor.run {
                groups = response
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct GroupRowView: View {
    let group: Group
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: group.avatarUrls?.thumb ?? "")) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(group.name)
                    .font(.headline)
                
                if let desc = group.description?.rendered {
                    Text(desc.stripHTML())
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Text("\(group.totalMemberCount ?? 0) members")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

struct GroupDetailView: View {
    let group: Group
    @State private var activities: [Activity] = []
    
    var body: some View {
        List {
            Section(header: Text("About")) {
                if let desc = group.description?.rendered {
                    Text(desc.stripHTML())
                }
                
                HStack {
                    Text("Members")
                    Spacer()
                    Text("\(group.totalMemberCount ?? 0)")
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(group.status ?? "Public")
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Activity")) {
                if activities.isEmpty {
                    Text("No activity yet")
                        .foregroundColor(.gray)
                } else {
                    ForEach(activities) { activity in
                        ActivityRowView(activity: activity)
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .task {
            await loadGroupActivity()
        }
    }
    
    private func loadGroupActivity() async {
        do {
            let response: [Activity] = try await APIManager.shared.request(
                endpoint: "/activity?group_id=\(group.id)&per_page=10"
            )
            await MainActor.run {
                activities = response
            }
        } catch {
            // Handle error
        }
    }
}
