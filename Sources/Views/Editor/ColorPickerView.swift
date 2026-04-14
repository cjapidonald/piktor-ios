import SwiftUI

struct ColorPickerView: View {
    @ObservedObject var editorState: EditorState

    // 32-color PICO-8 palette (matches web app)
    static let palette: [String] = [
        // Row 1
        "000000", "1D2B53", "7E2553", "008751",
        "AB5236", "5F574F", "C2C3C7", "FFF1E8",
        // Row 2
        "FF004D", "FFA300", "FFEC27", "00E436",
        "29ADFF", "83769C", "FF77A8", "FFCCAA",
        // Row 3
        "FFFFFF", "1A1C2C", "5D275D", "B13E53",
        "EF7D57", "FFCD75", "A7F070", "38B764",
        // Row 4
        "257179", "3B5DC9", "41A6F6", "73EFF7",
        "F4F4F4", "94B0C2", "566C86", "333C57",
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 12)

    var body: some View {
        VStack(spacing: 6) {
            // Palette grid
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Self.palette, id: \.self) { hex in
                    ColorCell(
                        hex: hex,
                        isSelected: editorState.selectedColor == hex,
                        action: { editorState.selectedColor = hex }
                    )
                }
            }
            .padding(.horizontal, 8)

            // Custom color row
            HStack(spacing: 8) {
                // Recently used or current color swatch
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: editorState.selectedColor))
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    )

                Text("#\(editorState.selectedColor)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                // Transparent (eraser shortcut)
                Button(action: {
                    editorState.selectedTool = .eraser
                }) {
                    HStack(spacing: 4) {
                        // Checkerboard pattern for "transparent"
                        ZStack {
                            HStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    Color.white.frame(width: 8, height: 8)
                                    Color.gray.frame(width: 8, height: 8)
                                }
                                VStack(spacing: 0) {
                                    Color.gray.frame(width: 8, height: 8)
                                    Color.white.frame(width: 8, height: 8)
                                }
                            }
                        }
                        .frame(width: 16, height: 16)
                        .cornerRadius(2)

                        Text("ERASE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "21262D"))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .background(Color(hex: "0D1117"))
    }
}

// MARK: - Color Cell

struct ColorCell: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: hex))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(
                            isSelected ? Color.white : Color.clear,
                            lineWidth: isSelected ? 2 : 0
                        )
                )
                .overlay(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(hex: "FFD700"), lineWidth: 1)
                            .padding(1)
                        : nil
                )
        }
    }
}

#Preview {
    ColorPickerView(editorState: EditorState(canvasSize: 16))
}
