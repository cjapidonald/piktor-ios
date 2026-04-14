import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Drawing Tool Enum
enum DrawingTool: String, CaseIterable {
    case pen = "Pen"
    case brush = "Brush"
    case spray = "Spray"
    case eraser = "Eraser"
    case fill = "Fill"
    case line = "Line"
    case rect = "Rect"
    case circle = "Circle"
    case gradient = "Gradient"
    case eyedropper = "Eyedropper"
    case text = "Text"

    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .brush: return "paintbrush"
        case .spray: return "aqi.medium"
        case .eraser: return "eraser"
        case .fill: return "drop.fill"
        case .line: return "line.diagonal"
        case .rect: return "rectangle"
        case .circle: return "circle"
        case .gradient: return "square.fill.on.square.fill"
        case .eyedropper: return "eyedropper"
        case .text: return "textformat"
        }
    }

    /// Whether this tool draws shapes via drag start/end
    var isShapeTool: Bool {
        switch self {
        case .line, .rect, .circle:
            return true
        default:
            return false
        }
    }
}

// MARK: - Mirror Mode
enum MirrorMode: String {
    case off
    case horizontal
    case vertical
    case both
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

    @Published var mirrorMode: MirrorMode = .off
    @Published var shapeStart: (Int, Int)? = nil

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

    // MARK: - Apply Color with Mirror Support

    /// Sets a pixel and its mirrored counterparts based on mirrorMode
    private func setPixelWithMirror(x: Int, y: Int, color: String?) {
        setPixel(x: x, y: y, color: color)

        if mirrorMode != .off {
            let mirrorH = mirrorMode == .horizontal || mirrorMode == .both
            let mirrorV = mirrorMode == .vertical || mirrorMode == .both
            let mirrored = DrawingTools.mirrorPoints(
                points: [(x, y)],
                canvasSize: canvasSize,
                horizontal: mirrorH,
                vertical: mirrorV
            )
            for (mx, my) in mirrored {
                setPixel(x: mx, y: my, color: color)
            }
        }
    }

    /// Applies color to a set of points with mirror support
    private func applyPointsWithMirror(_ points: [(Int, Int)], color: String?) {
        for (px, py) in points {
            setPixel(x: px, y: py, color: color)
        }

        if mirrorMode != .off {
            let mirrorH = mirrorMode == .horizontal || mirrorMode == .both
            let mirrorV = mirrorMode == .vertical || mirrorMode == .both
            let mirrored = DrawingTools.mirrorPoints(
                points: points,
                canvasSize: canvasSize,
                horizontal: mirrorH,
                vertical: mirrorV
            )
            for (mx, my) in mirrored {
                setPixel(x: mx, y: my, color: color)
            }
        }
    }

    // MARK: - Tool Actions

    func applyTool(at x: Int, y: Int) {
        switch selectedTool {
        case .pen:
            pushUndo()
            setPixelWithMirror(x: x, y: y, color: selectedColor)

        case .brush:
            pushUndo()
            let points = DrawingTools.brushPixels(x: x, y: y, radius: 2)
                .filter { $0.0 >= 0 && $0.0 < canvasSize && $0.1 >= 0 && $0.1 < canvasSize }
            applyPointsWithMirror(points, color: selectedColor)

        case .spray:
            pushUndo()
            let points = DrawingTools.sprayPixels(x: x, y: y, radius: 3, count: 8, canvasSize: canvasSize)
            applyPointsWithMirror(points, color: selectedColor)

        case .eraser:
            pushUndo()
            setPixelWithMirror(x: x, y: y, color: nil)

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

        case .line, .rect, .circle:
            // Shape tools: store start point on first touch
            shapeStart = (x, y)

        case .gradient:
            // For now, treat like pen
            pushUndo()
            setPixelWithMirror(x: x, y: y, color: selectedColor)

        case .text:
            // For now, treat like pen
            pushUndo()
            setPixelWithMirror(x: x, y: y, color: selectedColor)

        case .eyedropper:
            if let color = getPixel(x: x, y: y) {
                selectedColor = color
            }
        }
    }

    func applyToolDrag(at x: Int, y: Int) {
        switch selectedTool {
        case .pen:
            setPixelWithMirror(x: x, y: y, color: selectedColor)

        case .brush:
            let points = DrawingTools.brushPixels(x: x, y: y, radius: 2)
                .filter { $0.0 >= 0 && $0.0 < canvasSize && $0.1 >= 0 && $0.1 < canvasSize }
            applyPointsWithMirror(points, color: selectedColor)

        case .spray:
            let points = DrawingTools.sprayPixels(x: x, y: y, radius: 3, count: 5, canvasSize: canvasSize)
            applyPointsWithMirror(points, color: selectedColor)

        case .eraser:
            setPixelWithMirror(x: x, y: y, color: nil)

        case .gradient:
            setPixelWithMirror(x: x, y: y, color: selectedColor)

        case .text:
            setPixelWithMirror(x: x, y: y, color: selectedColor)

        case .fill, .eyedropper, .line, .rect, .circle:
            // These tools don't apply on drag (shapes are handled in canvas view)
            break
        }
    }

    /// Apply a shape tool on release (line, rect, circle)
    func applyShapeEnd(at x: Int, y: Int) {
        guard let start = shapeStart else { return }
        pushUndo()

        var shapePoints: [(Int, Int)] = []

        switch selectedTool {
        case .line:
            shapePoints = DrawingTools.linePixels(from: start, to: (x, y))

        case .rect:
            shapePoints = DrawingTools.rectanglePixels(x0: start.0, y0: start.1, x1: x, y1: y)

        case .circle:
            let cx = (start.0 + x) / 2
            let cy = (start.1 + y) / 2
            let rx = abs(x - start.0) / 2
            let ry = abs(y - start.1) / 2
            let r = max(rx, ry)
            shapePoints = DrawingTools.circlePixels(cx: cx, cy: cy, r: r)

        default:
            break
        }

        // Filter to canvas bounds
        let validPoints = shapePoints.filter {
            $0.0 >= 0 && $0.0 < canvasSize && $0.1 >= 0 && $0.1 < canvasSize
        }
        applyPointsWithMirror(validPoints, color: selectedColor)

        shapeStart = nil
    }

    /// Get preview pixels for the current shape being drawn
    func shapePreviewPixels(currentX: Int, currentY: Int) -> [(Int, Int)] {
        guard let start = shapeStart else { return [] }

        var shapePoints: [(Int, Int)] = []

        switch selectedTool {
        case .line:
            shapePoints = DrawingTools.linePixels(from: start, to: (currentX, currentY))

        case .rect:
            shapePoints = DrawingTools.rectanglePixels(x0: start.0, y0: start.1, x1: currentX, y1: currentY)

        case .circle:
            let cx = (start.0 + currentX) / 2
            let cy = (start.1 + currentY) / 2
            let rx = abs(currentX - start.0) / 2
            let ry = abs(currentY - start.1) / 2
            let r = max(rx, ry)
            shapePoints = DrawingTools.circlePixels(cx: cx, cy: cy, r: r)

        default:
            break
        }

        return shapePoints.filter {
            $0.0 >= 0 && $0.0 < canvasSize && $0.1 >= 0 && $0.1 < canvasSize
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
