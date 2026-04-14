import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Profile
struct Profile: Codable, Identifiable {
    let id: UUID
    let fullName: String?
    let role: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case role
        case avatarUrl = "avatar_url"
    }
}

// MARK: - World
struct World: Codable, Identifiable {
    let id: Int
    let name: String
    let theme: String?
    let colorHeader: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case theme
        case colorHeader = "color_header"
        case description
    }
}

// MARK: - PixelTask
struct PixelTask: Codable, Identifiable {
    let id: Int
    let worldId: Int?
    let category: String?
    let assetName: String?
    let description: String?
    let spritesNeeded: String?
    var status: String?
    let assignedTo: UUID?
    let canvasSize: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case worldId = "world_id"
        case category
        case assetName = "asset_name"
        case description
        case spritesNeeded = "sprites_needed"
        case status
        case assignedTo = "assigned_to"
        case canvasSize = "canvas_size"
        case createdAt = "created_at"
    }

    var statusEnum: TaskStatus {
        get { TaskStatus(rawValue: status ?? "not_started") ?? .notStarted }
        set { status = newValue.rawValue }
    }
}

enum TaskStatus: String, CaseIterable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case done = "done"
    case review = "review"

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        case .review: return "Review"
        }
    }

    var color: String {
        switch self {
        case .notStarted: return "9E9E9E"
        case .inProgress: return "FF9800"
        case .done: return "4CAF50"
        case .review: return "2196F3"
        }
    }

    var next: TaskStatus {
        switch self {
        case .notStarted: return .inProgress
        case .inProgress: return .review
        case .review: return .done
        case .done: return .notStarted
        }
    }
}

// MARK: - Drawing Data (pixel art payload)
struct DrawingData: Codable {
    var frames: [PixelFrame]
    var fps: Int

    init(frames: [PixelFrame] = [PixelFrame()], fps: Int = 12) {
        self.frames = frames
        self.fps = fps
    }
}

struct PixelFrame: Codable {
    var layers: [PixelLayer]

    init(layers: [PixelLayer] = [PixelLayer()]) {
        self.layers = layers
    }
}

struct PixelLayer: Codable {
    var name: String
    var visible: Bool
    var pixels: [String?]

    init(name: String = "Layer 1", visible: Bool = true, pixels: [String?] = []) {
        self.name = name
        self.visible = visible
        self.pixels = pixels
    }
}

// MARK: - Drawing (saved to Supabase)
struct Drawing: Codable, Identifiable {
    let id: UUID
    let taskId: Int?
    let userId: UUID?
    let canvasSize: Int?
    let pixelData: DrawingData?
    let imageUrl: String?
    let createdAt: String?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case userId = "user_id"
        case canvasSize = "canvas_size"
        case pixelData = "pixel_data"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case title
    }
}

// MARK: - Insert/Update structs
struct DrawingInsert: Codable {
    let taskId: Int?
    let userId: UUID
    let canvasSize: Int
    let pixelData: DrawingData
    let imageUrl: String?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case userId = "user_id"
        case canvasSize = "canvas_size"
        case pixelData = "pixel_data"
        case imageUrl = "image_url"
        case title
    }
}

struct TaskStatusUpdate: Codable {
    let status: String
}

// MARK: - Color Hex Extension
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgb >> 24) & 0xFF) / 255.0
            g = Double((rgb >> 16) & 0xFF) / 255.0
            b = Double((rgb >> 8) & 0xFF) / 255.0
            a = Double(rgb & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String? {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
        #else
        return nil
        #endif
    }
}

// MARK: - Blog Post
struct BlogPost: Codable, Identifiable {
    let id: UUID
    let title: String
    let slug: String
    let excerpt: String
    let content: String
    let coverImageUrl: String?
    let authorId: UUID
    let published: Bool
    let tags: [String]
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, slug, excerpt, content, published, tags
        case coverImageUrl = "cover_image_url"
        case authorId = "author_id"
        case createdAt = "created_at"
    }
}
