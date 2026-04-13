import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager

    @State private var stats: SupabaseManager.DashboardStats?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading dashboard...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") { loadStats() }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 40)
                    } else if let stats {
                        // Welcome header
                        welcomeHeader

                        // Stats cards grid
                        statsGrid(stats: stats)

                        // World progress bars
                        if !stats.worldStats.isEmpty {
                            worldProgressSection(stats: stats)
                        }
                    }
                }
                .padding()
            }
            .background(Color(hex: "0D1117"))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: signOut) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(Color(hex: "FFD700"))
                    }
                }
            }
            .refreshable { loadStats() }
            .onAppear { loadStats() }
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(supabaseManager.currentProfile?.fullName ?? "Artist")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "161B22"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "FFD700").opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Stats Grid

    private func statsGrid(stats: SupabaseManager.DashboardStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            StatCard(title: "Total", value: "\(stats.totalTasks)", color: "FFD700", icon: "square.grid.2x2")
            StatCard(title: "Done", value: "\(stats.doneTasks)", color: "4CAF50", icon: "checkmark.circle")
            StatCard(title: "In Progress", value: "\(stats.inProgressTasks)", color: "FF9800", icon: "clock")
            StatCard(title: "Not Started", value: "\(stats.notStartedTasks)", color: "9E9E9E", icon: "circle")
        }
    }

    // MARK: - World Progress

    private func worldProgressSection(stats: SupabaseManager.DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORLD PROGRESS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 10) {
                ForEach(stats.worldStats) { world in
                    WorldProgressRow(world: world)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func loadStats() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                stats = try await supabaseManager.fetchDashboardStats()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func signOut() {
        Task {
            try? await supabaseManager.signOut()
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: color))
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "161B22"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: color).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - World Progress Row

struct WorldProgressRow: View {
    let world: SupabaseManager.WorldStat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(world.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("\(world.done)/\(world.total)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "21262D"))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: world.colorHeader))
                        .frame(width: max(0, geo.size.width * world.progress), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "161B22"))
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(SupabaseManager.shared)
}
