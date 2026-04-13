import Foundation

enum DrawingTools {
    /// BFS Flood Fill
    /// Fills contiguous pixels of the same color starting from (startX, startY)
    static func floodFill(
        pixels: inout [String?],
        canvasSize: Int,
        startX: Int,
        startY: Int,
        targetColor: String?,
        fillColor: String
    ) {
        guard startX >= 0, startX < canvasSize, startY >= 0, startY < canvasSize else { return }

        let startIndex = startY * canvasSize + startX
        guard pixels[startIndex] == targetColor else { return }

        // BFS
        var queue: [(Int, Int)] = [(startX, startY)]
        var visited = Set<Int>()
        visited.insert(startIndex)

        let directions = [(0, -1), (0, 1), (-1, 0), (1, 0)]

        while !queue.isEmpty {
            let (cx, cy) = queue.removeFirst()
            let idx = cy * canvasSize + cx
            pixels[idx] = fillColor

            for (dx, dy) in directions {
                let nx = cx + dx
                let ny = cy + dy

                guard nx >= 0, nx < canvasSize, ny >= 0, ny < canvasSize else { continue }

                let nIdx = ny * canvasSize + nx
                guard !visited.contains(nIdx) else { continue }
                guard pixels[nIdx] == targetColor else { continue }

                visited.insert(nIdx)
                queue.append((nx, ny))
            }
        }
    }

    /// Bresenham line algorithm for smooth pen strokes
    static func linePixels(from start: (Int, Int), to end: (Int, Int)) -> [(Int, Int)] {
        var points: [(Int, Int)] = []

        var x0 = start.0
        var y0 = start.1
        let x1 = end.0
        let y1 = end.1

        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy

        while true {
            points.append((x0, y0))

            if x0 == x1 && y0 == y1 { break }

            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x0 += sx
            }
            if e2 < dx {
                err += dx
                y0 += sy
            }
        }

        return points
    }
}
