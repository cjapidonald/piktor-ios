import SwiftUI

struct DrawingsGalleryView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager

    @State private var drawings: [Drawing] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDrawing: Drawing?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading drawings...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                        Button("Retry") { loadDrawings() }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if drawings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No drawings yet")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("Open a task and start drawing!")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.7))

                        NavigationLink {
                            EditorView(canvasSize: AppConfig.defaultCanvasSize)
                                .environmentObject(supabaseManager)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("NEW DRAWING")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(hex: "FFD700"))
                            .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    VStack(spacing: 16) {
                        // New drawing button
                        NavigationLink {
                            EditorView(canvasSize: AppConfig.defaultCanvasSize)
                                .environmentObject(supabaseManager)
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("New Drawing")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Color(hex: "FFD700"))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "161B22"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "FFD700").opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }

                        // Gallery grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(drawings) { drawing in
                                DrawingCard(drawing: drawing)
                                    .onTapGesture { selectedDrawing = drawing }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(hex: "0D1117"))
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { loadDrawings() }
            .onAppear { loadDrawings() }
            .navigationDestination(item: $selectedDrawing) { drawing in
                EditorView(
                    taskId: drawing.taskId,
                    canvasSize: drawing.canvasSize ?? AppConfig.defaultCanvasSize,
                    drawing: drawing
                )
                .environmentObject(supabaseManager)
            }
        }
    }

    private func loadDrawings() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                drawings = try await supabaseManager.fetchDrawings()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Drawing Card

struct DrawingCard: View {
    let drawing: Drawing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail or placeholder
            ZStack {
                Color(hex: "1E1E1E")

                if let imageUrl = drawing.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                        case .failure:
                            pixelPlaceholder
                        case .empty:
                            ProgressView()
                                .tint(.secondary)
                        @unknown default:
                            pixelPlaceholder
                        }
                    }
                } else {
                    // Render preview from pixel data if available
                    pixelPreview
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(drawing.title ?? "Untitled")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let size = drawing.canvasSize {
                        Text("\(size)x\(size)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if let date = drawing.createdAt {
                        Text(formatDate(date))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "161B22"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "30363D"), lineWidth: 1)
                )
        )
    }

    private var pixelPlaceholder: some View {
        VStack {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(hex: "30363D"))
        }
    }

    @ViewBuilder
    private var pixelPreview: some View {
        if let data = drawing.pixelData,
           let frame = data.frames.first,
           let layer = frame.layers.first,
           let size = drawing.canvasSize {
            Canvas { context, viewSize in
                let pxSize = viewSize.width / CGFloat(size)
                for y in 0..<size {
                    for x in 0..<size {
                        let idx = y * size + x
                        if idx < layer.pixels.count, let hex = layer.pixels[idx] {
                            let rect = CGRect(
                                x: CGFloat(x) * pxSize,
                                y: CGFloat(y) * pxSize,
                                width: pxSize,
                                height: pxSize
                            )
                            context.fill(Path(rect), with: .color(Color(hex: hex)))
                        }
                    }
                }
            }
        } else {
            pixelPlaceholder
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString.prefix(10).description
            }
            return shortDate(date)
        }
        return shortDate(date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Make Drawing Hashable for navigation
extension Drawing: Hashable {
    static func == (lhs: Drawing, rhs: Drawing) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    DrawingsGalleryView()
        .environmentObject(SupabaseManager.shared)
}
