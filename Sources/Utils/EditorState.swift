import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Drawing Tool Enum
enum DrawingTool: String, CaseIterable {
    case pen = "Pen"
    case eraser = "Eraser"
    case fill = "Fill"
    case eyedropper = "Eyedropper"

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .eraser: return "eraser"
        case .fill: return "drop.fill"
        case .eyedropper: return "eyedropper"
        }
    }
}

// MARK: - Undo Action
struct CanvasAction {
    let pixels: [String?]
}

// MARK: - EditorState
@MainActor
class EditorState: ObservableObject {
    @Published var canvasSize: Int
    @Published var pixels: [String?]
    @Published var selectedTool: DrawingTool = .pen
    @Published var selectedColor: String = "000000"
    @Published var showGrid: Bool = true
    @Published var currentLayerIndex: Int = 0

    @Published var taskId: Int?
    @Published var drawingId: UUID?
    @Published var drawingTitle: String?

    @Published var isSaving: Bool = false
    @Published var saveError: String?
    @Published var saveSuccess: Bool = false

    @Published var zoomScale: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero

    private var undoStack: [CanvasAction] = []
    private var redoStack: [CanvasAction] = []
    private let maxUndoSteps = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init(canvasSize: Int = AppConfig.defaultCanvasSize, taskId: Int? = nil) {
        self.canvasSize = canvasSize
        self.taskId = taskId
        self.pixels = Array(repeating: nil, count: canvasSize * canvasSize)
    }

    // MARK: - Load from DrawingData

    func loadDrawingData(_ data: DrawingData, size: Int) {
        canvasSize = size
        pixels = Array(repeating: nil, count: size * size)

        guard let frame = data.frames.first,
              let layer = frame.layers.first else { return }

        let count = min(layer.pixels.count, pixels.count)
        for i in 0..<count {
            pixels[i] = layer.pixels[i]
        }

        undoStack.removeAll()
        redoStack.removeAll()
    }

    // MARK: - Export to DrawingData

    func toDrawingData() -> DrawingData {
        let layer = PixelLayer(name: "Layer 1", visible: true, pixels: pixels)
        let frame = PixelFrame(layers: [layer])
        return DrawingData(frames: [frame], fps: 12)
    }

    // MARK: - Pixel Operations

    func pixelIndex(x: Int, y: Int) -> Int? {
        guard x >= 0, x < canvasSize, y >= 0, y < canvasSize else { return nil }
        return y * canvasSize + x
    }

    func getPixel(x: Int, y: Int) -> String? {
        guard let idx = pixelIndex(x: x, y: y) else { return nil }
        return pixels[idx]
    }

    func setPixel(x: Int, y: Int, color: String?) {
        guard let idx = pixelIndex(x: x, y: y) else { return }
        pixels[idx] = color
    }

    // MARK: - Tool Actions

    func applyTool(at x: Int, y: Int) {
        switch selectedTool {
        case .pen:
            pushUndo()
            setPixel(x: x, y: y, color: selectedColor)

        case .eraser:
            pushUndo()
            setPixel(x: x, y: y, color: nil)

        case .fill:
            pushUndo()
            let targetColor = getPixel(x: x, y: y)
            if targetColor != selectedColor {
                DrawingTools.floodFill(
                    pixels: &pixels,
                    canvasSize: canvasSize,
                    startX: x,
                    startY: y,
                    targetColor: targetColor,
                    fillColor: selectedColor
                )
            }

        case .eyedropper:
            if let color = getPixel(x: x, y: y) {
                selectedColor = color
            }
        }
    }

    func applyToolDrag(at x: Int, y: Int) {
        switch selectedTool {
        case .pen:
            setPixel(x: x, y: y, color: selectedColor)
        case .eraser:
            setPixel(x: x, y: y, color: nil)
        case .fill, .eyedropper:
            break
        }
    }

    // MARK: - Undo / Redo

    func pushUndo() {
        undoStack.append(CanvasAction(pixels: pixels))
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        redoStack.append(CanvasAction(pixels: pixels))
        pixels = action.pixels
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }
        undoStack.append(CanvasAction(pixels: pixels))
        pixels = action.pixels
    }

    // MARK: - Clear Canvas

    func clearCanvas() {
        pushUndo()
        pixels = Array(repeating: nil, count: canvasSize * canvasSize)
    }

    // MARK: - Generate Thumbnail PNG

    func generateThumbnailData(scale: Int = 4) -> Data? {
        let size = canvasSize
        let imageSize = size * scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))

        let image = renderer.image { context in
            let ctx = context.cgContext

            // Transparent background
            ctx.clear(CGRect(x: 0, y: 0, width: imageSize, height: imageSize))

            for y in 0..<size {
                for x in 0..<size {
                    if let hex = pixels[y * size + x] {
                        let color = UIColor(Color(hex: hex))
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(CGRect(
                            x: x * scale,
                            y: y * scale,
                            width: scale,
                            height: scale
                        ))
                    }
                }
            }
        }

        return image.pngData()
    }

    // MARK: - Save to Supabase

    func save() async {
        isSaving = true
        saveError = nil
        saveSuccess = false

        do {
            let manager = SupabaseManager.shared
            let pixelData = toDrawingData()

            if let existingId = drawingId {
                // Update existing drawing
                try await manager.updateDrawing(drawingId: existingId, pixelData: pixelData)

                // Upload thumbnail
                if let thumbData = generateThumbnailData() {
                    _ = try await manager.uploadThumbnail(drawingId: existingId, imageData: thumbData)
                }
            } else {
                // Create new drawing
                let drawing = try await manager.saveDrawing(
                    taskId: taskId,
                    canvasSize: canvasSize,
                    pixelData: pixelData,
                    title: drawingTitle ?? "Untitled"
                )
                drawingId = drawing.id

                // Upload thumbnail
                if let thumbData = generateThumbnailData() {
                    _ = try await manager.uploadThumbnail(drawingId: drawing.id, imageData: thumbData)
                }
            }

            saveSuccess = true
        } catch {
            saveError = error.localizedDescription
            print("Save error: \(error)")
        }

        isSaving = false
    }
}
