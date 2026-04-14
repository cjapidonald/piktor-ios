import SwiftUI

struct ToolBarView: View {
    @ObservedObject var editorState: EditorState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showColorPicker = false
    @AppStorage("appThemeDark") private var isDarkTheme = true

    private let columns = [
        GridItem(.fixed(40), spacing: 4),
        GridItem(.fixed(40), spacing: 4)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 4) {
                // Row 1: Pen, Brush
                toolButton(tool: .pen)
                toolButton(tool: .brush)

                // Row 2: Spray, Eraser
                toolButton(tool: .spray)
                toolButton(tool: .eraser)

                // Row 3: Fill, Line
                toolButton(tool: .fill)
                toolButton(tool: .line)

                // Row 4: Rect, Circle
                toolButton(tool: .rect)
                toolButton(tool: .circle)

                // Row 5: Gradient, Eyedropper
                toolButton(tool: .gradient)
                toolButton(tool: .eyedropper)

                // Row 6: Text, Color picker
                toolButton(tool: .text)
                colorPickerButton

                // Row 7: Undo, Redo
                undoButton
                redoButton

                // Row 8: Mirror H, Mirror V
                mirrorButton(mode: .horizontal, icon: "arrow.left.and.right", label: "H")
                mirrorButton(mode: .vertical, icon: "arrow.up.and.down", label: "V")

                // Row 9: Mirror Both, Theme toggle
                mirrorButton(mode: .both, icon: "arrow.up.left.and.arrow.down.right", label: "HV")
                themeToggleButton
            }
            .padding(6)
        }
        .frame(width: 92)
        .background(Color(hex: "161B22"))
        .sheet(isPresented: $showColorPicker) {
            colorPickerSheet
        }
    }

    // MARK: - Tool Button

    private func toolButton(tool: DrawingTool) -> some View {
        Button {
            editorState.selectedTool = tool
        } label: {
            VStack(spacing: 1) {
                Image(systemName: tool.icon)
                    .font(.system(size: 16))
                Text(tool.rawValue)
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundColor(editorState.selectedTool == tool ? .white : .secondary)
            .frame(width: 40, height: 40)
            .background(
                editorState.selectedTool == tool
                    ? Color.green.opacity(0.2)
                    : Color.clear
            )
            .cornerRadius(6)
        }
    }

    // MARK: - Color Picker Button

    private var colorPickerButton: some View {
        Button {
            showColorPicker = true
        } label: {
            VStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: editorState.selectedColor))
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                Text("Color")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.secondary)
            .frame(width: 40, height: 40)
            .cornerRadius(6)
        }
    }

    // MARK: - Undo Button

    private var undoButton: some View {
        Button {
            editorState.undo()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16))
                Text("Undo")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
            }
            .foregroundColor(editorState.canUndo ? .white : Color(hex: "30363D"))
            .frame(width: 40, height: 40)
            .cornerRadius(6)
        }
        .disabled(!editorState.canUndo)
    }

    // MARK: - Redo Button

    private var redoButton: some View {
        Button {
            editorState.redo()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16))
                Text("Redo")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
            }
            .foregroundColor(editorState.canRedo ? .white : Color(hex: "30363D"))
            .frame(width: 40, height: 40)
            .cornerRadius(6)
        }
        .disabled(!editorState.canRedo)
    }

    // MARK: - Mirror Button

    private func mirrorButton(mode: MirrorMode, icon: String, label: String) -> some View {
        let isActive = editorState.mirrorMode == mode

        return Button {
            if editorState.mirrorMode == mode {
                editorState.mirrorMode = .off
            } else {
                editorState.mirrorMode = mode
            }
        } label: {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
            }
            .foregroundColor(isActive ? .white : .secondary)
            .frame(width: 40, height: 40)
            .background(isActive ? Color.green.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
    }

    // MARK: - Theme Toggle Button

    private var themeToggleButton: some View {
        Button {
            isDarkTheme.toggle()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: isDarkTheme ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 16))
                Text("Theme")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.secondary)
            .frame(width: 40, height: 40)
            .cornerRadius(6)
        }
    }

    // MARK: - Color Picker Sheet

    private var colorPickerSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                ColorPicker("Select Color", selection: Binding(
                    get: { Color(hex: editorState.selectedColor) },
                    set: { newColor in
                        if let components = UIColor(newColor).cgColor.components, components.count >= 3 {
                            let r = Int(components[0] * 255)
                            let g = Int(components[1] * 255)
                            let b = Int(components[2] * 255)
                            editorState.selectedColor = String(format: "%02X%02X%02X", r, g, b)
                        }
                    }
                ), supportsOpacity: false)
                .padding()

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: editorState.selectedColor))
                    .frame(height: 60)
                    .overlay(
                        Text("#\(editorState.selectedColor)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                    )
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Color Picker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showColorPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ToolBarView(editorState: EditorState(canvasSize: 16))
        .background(Color.black)
}
