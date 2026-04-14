import SwiftUI

struct PixelCanvasView: View {
    @ObservedObject var editorState: EditorState

    @State private var lastDragPixel: (Int, Int)?
    @State private var isDragging = false
    @State private var currentDragPixel: (Int, Int)?

    var body: some View {
        GeometryReader { geometry in
            let canvasRect = geometry.size
            let pixelSize = min(canvasRect.width, canvasRect.height) / CGFloat(editorState.canvasSize)

            Canvas { context, size in
                let gridSize = editorState.canvasSize
                let pxSize = min(size.width, size.height) / CGFloat(gridSize)

                // Draw checkerboard background (transparent indicator)
                for y in 0..<gridSize {
                    for x in 0..<gridSize {
                        let rect = CGRect(
                            x: CGFloat(x) * pxSize,
                            y: CGFloat(y) * pxSize,
                            width: pxSize,
                            height: pxSize
                        )

                        let idx = y * gridSize + x
                        if let hex = editorState.pixels[idx] {
                            // Draw pixel color
                            context.fill(
                                Path(rect),
                                with: .color(Color(hex: hex))
                            )
                        } else {
                            // Draw checkerboard for transparency
                            let isLight = (x + y) % 2 == 0
                            context.fill(
                                Path(rect),
                                with: .color(isLight ? Color(hex: "2A2A2A") : Color(hex: "1E1E1E"))
                            )
                        }
                    }
                }

                // Draw shape preview overlay during drag
                if editorState.selectedTool.isShapeTool,
                   editorState.shapeStart != nil,
                   let current = currentDragPixel {
                    let previewPixels = editorState.shapePreviewPixels(currentX: current.0, currentY: current.1)
                    let previewColor = Color(hex: editorState.selectedColor).opacity(0.6)

                    for (px, py) in previewPixels {
                        let previewRect = CGRect(
                            x: CGFloat(px) * pxSize,
                            y: CGFloat(py) * pxSize,
                            width: pxSize,
                            height: pxSize
                        )
                        context.fill(Path(previewRect), with: .color(previewColor))
                    }
                }

                // Draw grid lines for small canvases
                if editorState.showGrid && gridSize <= 64 {
                    let gridColor = Color.white.opacity(0.1)

                    for i in 0...gridSize {
                        let pos = CGFloat(i) * pxSize

                        // Vertical line
                        var vPath = Path()
                        vPath.move(to: CGPoint(x: pos, y: 0))
                        vPath.addLine(to: CGPoint(x: pos, y: CGFloat(gridSize) * pxSize))
                        context.stroke(vPath, with: .color(gridColor), lineWidth: 0.5)

                        // Horizontal line
                        var hPath = Path()
                        hPath.move(to: CGPoint(x: 0, y: pos))
                        hPath.addLine(to: CGPoint(x: CGFloat(gridSize) * pxSize, y: pos))
                        context.stroke(hPath, with: .color(gridColor), lineWidth: 0.5)
                    }
                }

                // Canvas border
                let borderRect = CGRect(x: 0, y: 0, width: CGFloat(gridSize) * pxSize, height: CGFloat(gridSize) * pxSize)
                context.stroke(
                    Path(borderRect),
                    with: .color(Color(hex: "30363D")),
                    lineWidth: 1
                )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = Int(value.location.x / pixelSize)
                        let y = Int(value.location.y / pixelSize)

                        guard x >= 0, x < editorState.canvasSize,
                              y >= 0, y < editorState.canvasSize else { return }

                        if editorState.selectedTool.isShapeTool {
                            // Shape tools: record start on first touch, update preview on drag
                            if !isDragging {
                                isDragging = true
                                editorState.applyTool(at: x, y: y) // stores shapeStart
                                currentDragPixel = (x, y)
                            } else {
                                currentDragPixel = (x, y)
                            }
                        } else {
                            // Non-shape tools: standard behavior
                            if !isDragging {
                                // First touch
                                isDragging = true
                                lastDragPixel = (x, y)
                                editorState.applyTool(at: x, y: y)
                            } else if let last = lastDragPixel, (last.0 != x || last.1 != y) {
                                // Dragging to new pixel - use Bresenham for smooth lines
                                let linePixels = DrawingTools.linePixels(from: last, to: (x, y))
                                for (px, py) in linePixels {
                                    editorState.applyToolDrag(at: px, y: py)
                                }
                                lastDragPixel = (x, y)
                            }
                        }
                    }
                    .onEnded { value in
                        if editorState.selectedTool.isShapeTool {
                            // Shape tools: calculate final shape and apply on release
                            let x = Int(value.location.x / pixelSize)
                            let y = Int(value.location.y / pixelSize)
                            let clampedX = max(0, min(editorState.canvasSize - 1, x))
                            let clampedY = max(0, min(editorState.canvasSize - 1, y))
                            editorState.applyShapeEnd(at: clampedX, y: clampedY)
                            currentDragPixel = nil
                        }

                        isDragging = false
                        lastDragPixel = nil
                    }
            )
            .contentShape(Rectangle())
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(Rectangle())
    }
}

#Preview {
    let state = EditorState(canvasSize: 16)
    // Pre-fill some pixels for preview
    state.pixels[0] = "FF0000"
    state.pixels[1] = "00FF00"
    state.pixels[2] = "0000FF"
    state.pixels[16] = "FFD700"
    state.pixels[17] = "FF8C00"

    return PixelCanvasView(editorState: state)
        .frame(width: 300, height: 300)
        .background(Color.black)
}
