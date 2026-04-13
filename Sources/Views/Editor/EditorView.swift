import SwiftUI

struct EditorView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @StateObject private var editorState: EditorState
    @Environment(\.dismiss) private var dismiss

    @State private var showSaveAlert = false
    @State private var showClearAlert = false

    init(taskId: Int? = nil, canvasSize: Int = AppConfig.defaultCanvasSize, drawing: Drawing? = nil) {
        let state = EditorState(canvasSize: canvasSize, taskId: taskId)

        if let drawing = drawing {
            state.drawingId = drawing.id
            state.drawingTitle = drawing.title
            if let data = drawing.pixelData, let size = drawing.canvasSize {
                state.loadDrawingData(data, size: size)
            }
        }

        _editorState = StateObject(wrappedValue: state)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            editorToolbar

            // Canvas area
            GeometryReader { geometry in
                ZStack {
                    Color(hex: "0D1117")

                    PixelCanvasView(editorState: editorState)
                        .frame(
                            width: min(geometry.size.width - 16, geometry.size.height - 16),
                            height: min(geometry.size.width - 16, geometry.size.height - 16)
                        )
                        .scaleEffect(editorState.zoomScale)
                        .offset(editorState.panOffset)
                        .gesture(magnificationGesture)
                }
            }

            // Tool bar
            ToolBarView(editorState: editorState)

            // Color picker
            ColorPickerView(editorState: editorState)
        }
        .background(Color(hex: "0D1117"))
        .navigationBarHidden(true)
        .alert("Clear Canvas?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                editorState.clearCanvas()
            }
        } message: {
            Text("This will erase all pixels. You can undo this action.")
        }
        .alert("Saved!", isPresented: $editorState.saveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your drawing has been saved to the cloud.")
        }
        .alert("Save Error", isPresented: .init(
            get: { editorState.saveError != nil },
            set: { if !$0 { editorState.saveError = nil } }
        )) {
            Button("OK") { editorState.saveError = nil }
        } message: {
            Text(editorState.saveError ?? "Unknown error")
        }
    }

    // MARK: - Editor Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "FFD700"))
            }

            // Title
            VStack(alignment: .leading, spacing: 1) {
                Text(editorState.drawingTitle ?? "New Drawing")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(editorState.canvasSize)x\(editorState.canvasSize)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Undo
            Button(action: { editorState.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16))
                    .foregroundColor(editorState.canUndo ? .white : Color(hex: "30363D"))
            }
            .disabled(!editorState.canUndo)

            // Redo
            Button(action: { editorState.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16))
                    .foregroundColor(editorState.canRedo ? .white : Color(hex: "30363D"))
            }
            .disabled(!editorState.canRedo)

            // Grid toggle
            Button(action: { editorState.showGrid.toggle() }) {
                Image(systemName: editorState.showGrid ? "grid" : "grid.circle")
                    .font(.system(size: 16))
                    .foregroundColor(editorState.showGrid ? Color(hex: "FFD700") : .secondary)
            }

            // Clear
            Button(action: { showClearAlert = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
            }

            // Save
            Button(action: { Task { await editorState.save() } }) {
                HStack(spacing: 4) {
                    if editorState.isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                    }
                    Text("SAVE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "FFD700"))
                .cornerRadius(6)
            }
            .disabled(editorState.isSaving)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "161B22"))
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                editorState.zoomScale = max(0.5, min(5.0, value.magnification))
            }
    }
}

#Preview {
    EditorView(taskId: nil, canvasSize: 16)
        .environmentObject(SupabaseManager.shared)
}
