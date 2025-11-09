//
//  SplashScreenView.swift
//  GRead
//
//  Created by apple on 11/8/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 45/255, green: 52/255, blue: 96/255),
                    Color(red: 30/255, green: 35/255, blue: 65/255)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Content
            if isActive {
                // App has loaded, show main content
                ZStack {
                    // This will be replaced by the actual app content
                    Color.clear
                }
                .transition(.opacity)
            } else {
                // Splash screen
                VStack(spacing: 20) {
                    Spacer()

                    // App Icon
                    Image("appstore1024")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(30)
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                        .scaleEffect(scale)
                        .opacity(opacity)

                    // App Name
                    Text("GRead")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(opacity)

                    // Tagline
                    Text("Track Your Reading Journey")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(opacity)

                    Spacer()

                    // Loading indicator
                    ProgressView()
                        .tint(.white)
                        .opacity(opacity)
                        .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // Animate in
                    withAnimation(.easeOut(duration: 0.8)) {
                        scale = 1.0
                        opacity = 1.0
                    }

                    // Dismiss splash after 2.5 seconds with fade out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.6)) {
                            opacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isActive = true
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
