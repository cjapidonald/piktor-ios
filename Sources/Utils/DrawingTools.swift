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

    // MARK: - Rectangle Outline

    /// Returns the outline pixels of a rectangle defined by two corners
    static func rectanglePixels(x0: Int, y0: Int, x1: Int, y1: Int) -> [(Int, Int)] {
        let minX = min(x0, x1)
        let maxX = max(x0, x1)
        let minY = min(y0, y1)
        let maxY = max(y0, y1)

        var points: [(Int, Int)] = []

        // Top and bottom edges
        for x in minX...maxX {
            points.append((x, minY))
            points.append((x, maxY))
        }
        // Left and right edges (excluding corners already added)
        if maxY > minY + 1 {
            for y in (minY + 1)..<maxY {
                points.append((minX, y))
                points.append((maxX, y))
            }
        }

        return points
    }

    // MARK: - Midpoint Circle

    /// Midpoint circle algorithm - returns outline pixels of a circle
    static func circlePixels(cx: Int, cy: Int, r: Int) -> [(Int, Int)] {
        guard r > 0 else { return [(cx, cy)] }

        var points: [(Int, Int)] = []
        var x = r
        var y = 0
        var d = 1 - r

        while x >= y {
            points.append((cx + x, cy + y))
            points.append((cx - x, cy + y))
            points.append((cx + x, cy - y))
            points.append((cx - x, cy - y))
            points.append((cx + y, cy + x))
            points.append((cx - y, cy + x))
            points.append((cx + y, cy - x))
            points.append((cx - y, cy - x))

            y += 1
            if d <= 0 {
                d += 2 * y + 1
            } else {
                x -= 1
                d += 2 * (y - x) + 1
            }
        }

        return points
    }

    // MARK: - Spray

    /// Returns random pixels within a radius (for spray tool)
    static func sprayPixels(x: Int, y: Int, radius: Int, count: Int, canvasSize: Int) -> [(Int, Int)] {
        var points: [(Int, Int)] = []
        let radiusSq = radius * radius

        for _ in 0..<count {
            let dx = Int.random(in: -radius...radius)
            let dy = Int.random(in: -radius...radius)
            if dx * dx + dy * dy <= radiusSq {
                let nx = x + dx
                let ny = y + dy
                if nx >= 0, nx < canvasSize, ny >= 0, ny < canvasSize {
                    points.append((nx, ny))
                }
            }
        }

        return points
    }

    // MARK: - Brush (Filled Circle)

    /// Returns all pixels in a filled circle (for brush tool)
    static func brushPixels(x: Int, y: Int, radius: Int) -> [(Int, Int)] {
        var points: [(Int, Int)] = []
        let radiusSq = radius * radius

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy <= radiusSq {
                    points.append((x + dx, y + dy))
                }
            }
        }

        return points
    }

    // MARK: - Mirror Points

    /// Mirrors a set of points across horizontal, vertical, or both axes
    static func mirrorPoints(
        points: [(Int, Int)],
        canvasSize: Int,
        horizontal: Bool,
        vertical: Bool
    ) -> [(Int, Int)] {
        var mirrored: [(Int, Int)] = []
        let maxIdx = canvasSize - 1

        for (px, py) in points {
            if horizontal {
                let mx = maxIdx - px
                if mx >= 0, mx < canvasSize, py >= 0, py < canvasSize {
                    mirrored.append((mx, py))
                }
            }
            if vertical {
                let my = maxIdx - py
                if px >= 0, px < canvasSize, my >= 0, my < canvasSize {
                    mirrored.append((px, my))
                }
            }
            if horizontal && vertical {
                let mx = maxIdx - px
                let my = maxIdx - py
                if mx >= 0, mx < canvasSize, my >= 0, my < canvasSize {
                    mirrored.append((mx, my))
                }
            }
        }

        return mirrored
    }
}
