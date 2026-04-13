import SwiftUI

@main
struct PiktorApp: App {
    @StateObject private var supabaseManager = SupabaseManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(supabaseManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var isCheckingSession = true

    var body: some View {
        Group {
            if isCheckingSession {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .foregroundColor(.white)
            } else if supabaseManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await supabaseManager.checkSession()
            isCheckingSession = false
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }

            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            DrawingsGalleryView()
                .tabItem {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
        }
        .tint(Color(hex: "FFD700"))
    }
}
