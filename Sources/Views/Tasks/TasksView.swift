import SwiftUI

struct TasksView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager

    @State private var tasks: [PixelTask] = []
    @State private var worlds: [World] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var selectedWorldId: Int? = nil
    @State private var selectedStatus: String? = nil
    @State private var showMyTasksOnly = false
    @State private var navigateToEditor: PixelTask?

    var filteredTasks: [PixelTask] {
        var result = tasks

        if let worldId = selectedWorldId {
            result = result.filter { $0.worldId == worldId }
        }

        if let status = selectedStatus {
            result = result.filter { ($0.status ?? "not_started") == status }
        }

        if showMyTasksOnly, let userId = supabaseManager.currentUser?.id {
            result = result.filter { $0.assignedTo == userId }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                // Task list
                if isLoading {
                    Spacer()
                    ProgressView("Loading tasks...")
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                        Button("Retry") { loadData() }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else if filteredTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No tasks found")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredTasks) { task in
                                TaskRow(
                                    task: task,
                                    worldName: worldName(for: task.worldId),
                                    onStatusTap: { cycleStatus(task: task) },
                                    onDrawTap: { navigateToEditor = task }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(hex: "0D1117"))
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { loadData() }
            .onAppear { loadData() }
            .navigationDestination(item: $navigateToEditor) { task in
                EditorView(taskId: task.id, canvasSize: task.canvasSize ?? AppConfig.defaultCanvasSize)
                    .environmentObject(supabaseManager)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // World filter
                Menu {
                    Button("All Worlds") { selectedWorldId = nil }
                    ForEach(worlds) { world in
                        Button(world.name) { selectedWorldId = world.id }
                    }
                } label: {
                    FilterChip(
                        label: selectedWorldId.flatMap { id in worlds.first { $0.id == id }?.name } ?? "World",
                        isActive: selectedWorldId != nil
                    )
                }

                // Status filter
                Menu {
                    Button("All Statuses") { selectedStatus = nil }
                    ForEach(TaskStatus.allCases, id: \.rawValue) { status in
                        Button(status.displayName) { selectedStatus = status.rawValue }
                    }
                } label: {
                    FilterChip(
                        label: selectedStatus.flatMap { TaskStatus(rawValue: $0)?.displayName } ?? "Status",
                        isActive: selectedStatus != nil
                    )
                }

                // My tasks toggle
                Button(action: { showMyTasksOnly.toggle() }) {
                    FilterChip(
                        label: "My Tasks",
                        isActive: showMyTasksOnly
                    )
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(hex: "161B22"))
    }

    // MARK: - Helpers

    private func worldName(for worldId: Int?) -> String {
        guard let id = worldId else { return "Unassigned" }
        return worlds.first { $0.id == id }?.name ?? "World \(id)"
    }

    private func loadData() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                async let tasksResult = supabaseManager.fetchTasks()
                async let worldsResult = supabaseManager.fetchWorlds()
                tasks = try await tasksResult
                worlds = try await worldsResult
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func cycleStatus(task: PixelTask) {
        let currentStatus = TaskStatus(rawValue: task.status ?? "not_started") ?? .notStarted
        let newStatus = currentStatus.next

        Task {
            do {
                try await supabaseManager.updateTaskStatus(taskId: task.id, status: newStatus.rawValue)
                // Update local state
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[idx].status = newStatus.rawValue
                }
            } catch {
                print("Error updating status: \(error)")
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: PixelTask
    let worldName: String
    let onStatusTap: () -> Void
    let onDrawTap: () -> Void

    private var status: TaskStatus {
        TaskStatus(rawValue: task.status ?? "not_started") ?? .notStarted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: asset name + category
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.assetName ?? "Untitled")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(worldName)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "FFD700"))

                        if let category = task.category {
                            Text("| \(category)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Canvas size badge
                if let size = task.canvasSize {
                    Text("\(size)x\(size)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "21262D"))
                        .cornerRadius(4)
                }
            }

            // Description
            if let desc = task.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Bottom: status badge + sprites needed + draw button
            HStack {
                // Tappable status badge
                Button(action: onStatusTap) {
                    Text(status.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: status.color))
                        .cornerRadius(4)
                }

                if let sprites = task.spritesNeeded, !sprites.isEmpty {
                    Text(sprites)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Draw button
                Button(action: onDrawTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 12))
                        Text("DRAW")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "FFD700"))
                    .cornerRadius(6)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "161B22"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "30363D"), lineWidth: 1)
                )
        )
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isActive: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(isActive ? .black : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color(hex: "FFD700") : Color(hex: "21262D"))
            .cornerRadius(16)
    }
}

// MARK: - Make PixelTask Hashable for navigation
extension PixelTask: Hashable {
    static func == (lhs: PixelTask, rhs: PixelTask) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    TasksView()
        .environmentObject(SupabaseManager.shared)
}
