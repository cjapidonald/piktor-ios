import Foundation
import Supabase
import Auth
import Storage
import SwiftUI

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    @Published var isAuthenticated = false
    @Published var currentUser: Auth.User?
    @Published var currentProfile: Profile?

    private init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }

    // MARK: - Auth

    func checkSession() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
            await fetchProfile()
        } catch {
            isAuthenticated = false
            currentUser = nil
            currentProfile = nil
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        currentUser = session.user
        isAuthenticated = true
        await fetchProfile()
    }

    func signUp(email: String, password: String, fullName: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        // signUp returns an AuthResponse. Check if a session is present (auto-confirm enabled).
        if let session = response.session {
            currentUser = session.user
            isAuthenticated = true
        } else if let user = response.user {
            // User created but may need email confirmation
            currentUser = user
            isAuthenticated = false
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        currentProfile = nil
        isAuthenticated = false
    }

    // MARK: - Profile

    func fetchProfile() async {
        guard let userId = currentUser?.id else { return }
        do {
            let profile: Profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            currentProfile = profile
        } catch {
            print("Error fetching profile: \(error)")
        }
    }

    var isManager: Bool {
        currentProfile?.role == "manager" || currentProfile?.role == "admin"
    }

    // MARK: - Worlds

    func fetchWorlds() async throws -> [World] {
        let worlds: [World] = try await client
            .from("worlds")
            .select()
            .order("id")
            .execute()
            .value
        return worlds
    }

    // MARK: - Tasks

    func fetchTasks() async throws -> [PixelTask] {
        let tasks: [PixelTask] = try await client
            .from("tasks")
            .select()
            .order("id")
            .execute()
            .value
        return tasks
    }

    func fetchTasks(worldId: Int) async throws -> [PixelTask] {
        let tasks: [PixelTask] = try await client
            .from("tasks")
            .select()
            .eq("world_id", value: worldId)
            .order("id")
            .execute()
            .value
        return tasks
    }

    func fetchMyTasks() async throws -> [PixelTask] {
        guard let userId = currentUser?.id else { return [] }
        let tasks: [PixelTask] = try await client
            .from("tasks")
            .select()
            .eq("assigned_to", value: userId.uuidString)
            .order("id")
            .execute()
            .value
        return tasks
    }

    func updateTaskStatus(taskId: Int, status: String) async throws {
        try await client
            .from("tasks")
            .update(TaskStatusUpdate(status: status))
            .eq("id", value: taskId)
            .execute()
    }

    // MARK: - Drawings

    func fetchDrawings() async throws -> [Drawing] {
        guard let userId = currentUser?.id else { return [] }
        let drawings: [Drawing] = try await client
            .from("drawings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return drawings
    }

    func fetchDrawingsForTask(taskId: Int) async throws -> [Drawing] {
        let drawings: [Drawing] = try await client
            .from("drawings")
            .select()
            .eq("task_id", value: taskId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return drawings
    }

    func saveDrawing(taskId: Int?, canvasSize: Int, pixelData: DrawingData, title: String?) async throws -> Drawing {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "Piktor", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let insert = DrawingInsert(
            taskId: taskId,
            userId: userId,
            canvasSize: canvasSize,
            pixelData: pixelData,
            imageUrl: nil,
            title: title
        )

        let drawing: Drawing = try await client
            .from("drawings")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return drawing
    }

    func updateDrawing(drawingId: UUID, pixelData: DrawingData) async throws {
        struct PixelDataUpdate: Codable {
            let pixelData: DrawingData
            enum CodingKeys: String, CodingKey {
                case pixelData = "pixel_data"
            }
        }

        try await client
            .from("drawings")
            .update(PixelDataUpdate(pixelData: pixelData))
            .eq("id", value: drawingId.uuidString)
            .execute()
    }

    // MARK: - Storage

    func uploadThumbnail(drawingId: UUID, imageData: Data) async throws -> String {
        let path = "thumbnails/\(drawingId.uuidString).png"

        try await client.storage
            .from(AppConfig.drawingsBucket)
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(contentType: "image/png", upsert: true)
            )

        let publicURL = try client.storage
            .from(AppConfig.drawingsBucket)
            .getPublicURL(path: path)

        // Update the drawing record with the image URL
        struct ImageURLUpdate: Codable {
            let imageUrl: String
            enum CodingKeys: String, CodingKey {
                case imageUrl = "image_url"
            }
        }

        try await client
            .from("drawings")
            .update(ImageURLUpdate(imageUrl: publicURL.absoluteString))
            .eq("id", value: drawingId.uuidString)
            .execute()

        return publicURL.absoluteString
    }

    // MARK: - Dashboard Stats

    struct DashboardStats {
        var totalTasks: Int = 0
        var doneTasks: Int = 0
        var inProgressTasks: Int = 0
        var notStartedTasks: Int = 0
        var reviewTasks: Int = 0
        var worldStats: [WorldStat] = []
    }

    struct WorldStat: Identifiable {
        let id: Int
        let name: String
        let colorHeader: String
        var total: Int
        var done: Int

        var progress: Double {
            guard total > 0 else { return 0 }
            return Double(done) / Double(total)
        }
    }

    func fetchDashboardStats() async throws -> DashboardStats {
        let tasks = try await fetchTasks()
        let worlds = try await fetchWorlds()

        var stats = DashboardStats()
        stats.totalTasks = tasks.count
        stats.doneTasks = tasks.filter { $0.status == "done" }.count
        stats.inProgressTasks = tasks.filter { $0.status == "in_progress" }.count
        stats.notStartedTasks = tasks.filter { $0.status == "not_started" || $0.status == nil }.count
        stats.reviewTasks = tasks.filter { $0.status == "review" }.count

        stats.worldStats = worlds.map { world in
            let worldTasks = tasks.filter { $0.worldId == world.id }
            return WorldStat(
                id: world.id,
                name: world.name,
                colorHeader: world.colorHeader ?? "FFD700",
                total: worldTasks.count,
                done: worldTasks.filter { $0.status == "done" }.count
            )
        }

        return stats
    }
}
