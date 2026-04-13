import SwiftUI

struct ToolBarView: View {
    @ObservedObject var editorState: EditorState

    var body: some View {
        HStack(spacing: 0) {
            // Drawing tools
            ForEach(DrawingTool.allCases, id: \.rawValue) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: editorState.selectedTool == tool,
                    action: { editorState.selectedTool = tool }
                )
            }

            Spacer()

            // Current color indicator
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: editorState.selectedColor))
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )

                Text("#\(editorState.selectedColor)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: "161B22"))
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: DrawingTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: tool.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Color(hex: "FFD700") : .secondary)

                Text(tool.rawValue)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? Color(hex: "FFD700") : .secondary)
            }
            .frame(width: 56, height: 44)
            .background(
                isSelected
                    ? Color(hex: "FFD700").opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(8)
        }
    }
}

#Preview {
    ToolBarView(editorState: EditorState(canvasSize: 16))
        .background(Color.black)
}
