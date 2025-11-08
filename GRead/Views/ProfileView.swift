//
//  ProfileView.swift
//  GRead
//
//  Created by apple on 11/6/25.
//

import SwiftUI


struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
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
                    
                    Section(header: Text("Settings")) {
                        NavigationLink("Edit Profile") {
                            Text("Edit Profile")
                        }

                        NavigationLink("Privacy") {
                            Text("Privacy Settings")
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
        }
    }
}
