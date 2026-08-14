import SwiftUI
import SpriteKit

// Published by GameScene so SwiftUI chrome only shows over the menu.
final class GameBridge: ObservableObject {
    @Published var inMenu = true
    // Set by the scene when the pilot card is tapped — opens the Hangar sheet.
    @Published var openHangar = false
}

struct RootView: View {
    @State private var scene: GameScene = {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        return scene
    }()
    @StateObject private var bridge = GameBridge()
    @State private var profile: Profile? = ProfileStore.load()
    @State private var pendingAvatar = Int.random(in: 0..<Avatars.count)
    @State private var showProfile = false
    @State private var showLeaderboard = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 120)
                .ignoresSafeArea()

            if bridge.inMenu {
                VStack {
                    HStack {
                        chromeButton("person.crop.circle", id: "profileButton") { showProfile = true }
                        Spacer()
                        chromeButton("trophy", id: "leaderboardButton") { showLeaderboard = true }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    Spacer()
                }
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .fullScreenCover(isPresented: .constant(profile == nil && !showSplash)) {
            OnboardingView(initialAvatar: pendingAvatar) { newProfile in
                profile = newProfile
                ProfileStore.save(newProfile)
                Backend.upsertUser(newProfile)
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView()
        }
        .sheet(isPresented: $bridge.openHangar, onDismiss: { scene.refreshAfterHangar() }) {
            HangarView()
        }
        .sheet(isPresented: $showProfile) {
            if let profile {
                ProfileView(profile: profile) { updated in
                    self.profile = updated
                    ProfileStore.save(updated)
                    Backend.updateProfile(updated)
                } onDelete: {
                    Backend.deleteAccount()
                    ProfileStore.clear()
                    self.profile = nil
                    pendingAvatar = Int.random(in: 0..<Avatars.count)
                }
            }
        }
        .onAppear {
            scene.bridge = bridge
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
                // After the splash so the ATT prompt lands on a settled screen.
                // Skipped during screenshot automation runs.
                if !ProcessInfo.processInfo.arguments.contains("-screenshots") {
                    AdsManager.shared.start()
                }
            }
        }
    }

    private func chromeButton(_ symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 46, height: 46)
                .background(Theme.card, in: Circle())
        }
        .accessibilityIdentifier(id)
    }
}
