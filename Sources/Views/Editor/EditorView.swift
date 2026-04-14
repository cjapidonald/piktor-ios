import SwiftUI

struct EditorView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @StateObject private var editorState: EditorState
    @Environment(\.dismiss) private var dismiss

    @State private var showClearAlert = false
    @State private var showColorPicker = false

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

    // MARK: - Body (matches webapp mobile layout)

    var body: some View {
        VStack(spacing: 0) {
            // Canvas fills all available space
            GeometryReader { geometry in
                ZStack {
                    Color(hex: "0D1117")

                    PixelCanvasView(editorState: editorState)
                        .frame(
                            width: min(geometry.size.width - 8, geometry.size.height - 8),
                            height: min(geometry.size.width - 8, geometry.size.height - 8)
                        )
                        .scaleEffect(editorState.zoomScale)
                        .offset(editorState.panOffset)
                        .gesture(magnificationGesture)
                }
            }

            // Save toast
            if editorState.saveSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Saved!")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color(hex: "6EE7B7"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(hex: "065F46").opacity(0.85))
            }

            if let error = editorState.saveError {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Save failed")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color(hex: "FCA5A5"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(hex: "B91C1C").opacity(0.85))
            }

            // Color palette strip (toggleable)
            if showColorPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(ColorPickerView.palette, id: \.self) { hex in
                            Button {
                                editorState.selectedColor = hex
                                showColorPicker = false
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: hex))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(
                                                editorState.selectedColor == hex ? Color.white : Color.clear,
                                                lineWidth: editorState.selectedColor == hex ? 2 : 0
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .background(Color(hex: "161B22"))
            }

            // Bottom toolbar — 3 rows of 7 (matches webapp grid-cols-7)
            VStack(spacing: 0) {
                // Row 1: pen, brush, spray, eraser, fill, line, rect
                HStack(spacing: 0) {
                    tbTool(.pen)
                    tbTool(.brush)
                    tbTool(.spray)
                    tbTool(.eraser)
                    tbTool(.fill)
                    tbTool(.line)
                    tbTool(.rect)
                }

                // Row 2: circle, gradient, eyedropper, text, color, undo, save
                HStack(spacing: 0) {
                    tbTool(.circle)
                    tbTool(.gradient)
                    tbTool(.eyedropper)
                    tbTool(.text)

                    // Color swatch
                    Button { showColorPicker.toggle() } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: editorState.selectedColor))
                            .frame(width: 22, height: 22)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)

                    // Undo
                    Button { editorState.undo() } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16))
                            .foregroundColor(editorState.canUndo ? Color(hex: "9CA3AF") : Color(hex: "374151"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)

                    // Save (green)
                    Button { Task { await editorState.save() } } label: {
                        Group {
                            if editorState.isSaving {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 16))
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "22C55E"))
                    .disabled(editorState.isSaving)
                }

                // Row 3: mirrorH, mirrorV, mirrorBoth, size, redo, clear, back
                HStack(spacing: 0) {
                    tbMirror("H", isActive: editorState.mirrorMode == .horizontal || editorState.mirrorMode == .both) {
                        switch editorState.mirrorMode {
                        case .off: editorState.mirrorMode = .horizontal
                        case .horizontal: editorState.mirrorMode = .off
                        case .vertical: editorState.mirrorMode = .both
                        case .both: editorState.mirrorMode = .vertical
                        }
                    }
                    tbMirror("V", isActive: editorState.mirrorMode == .vertical || editorState.mirrorMode == .both) {
                        switch editorState.mirrorMode {
                        case .off: editorState.mirrorMode = .vertical
                        case .vertical: editorState.mirrorMode = .off
                        case .horizontal: editorState.mirrorMode = .both
                        case .both: editorState.mirrorMode = .horizontal
                        }
                    }
                    tbMirror("HV", isActive: editorState.mirrorMode == .both) {
                        editorState.mirrorMode = editorState.mirrorMode == .both ? .off : .both
                    }

                    // Canvas size
                    Text("\(editorState.canvasSize)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)

                    // Redo
                    Button { editorState.redo() } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 16))
                            .foregroundColor(editorState.canRedo ? Color(hex: "9CA3AF") : Color(hex: "374151"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)

                    // Clear
                    Button { showClearAlert = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)

                    // Back (green)
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "22C55E"))
                }
            }
            .background(Color(hex: "0D1117"))
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

    // MARK: - Tool Button

    private func tbTool(_ tool: DrawingTool) -> some View {
        let isActive = editorState.selectedTool == tool
        return Button {
            editorState.selectedTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 16))
                .foregroundColor(isActive ? .white : Color(hex: "9CA3AF"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(isActive ? Color(hex: "374151") : Color.clear)
    }

    // MARK: - Mirror Button

    private func tbMirror(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? .white : Color(hex: "9CA3AF"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(isActive ? Color(hex: "374151") : Color.clear)
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
