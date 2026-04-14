import SwiftUI

struct LoginView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSignUp = false

    // Quadrant background colors (bee theme)
    private let quadrantColors: [Color] = [
        Color(hex: "FFD700"), // Gold
        Color(hex: "FF8C00"), // Dark Orange
        Color(hex: "1A1A2E"), // Dark Navy
        Color(hex: "16213E"), // Deep Blue
    ]

    var body: some View {
        ZStack {
            // 4-quadrant themed background
            backgroundView

            // Login card
            VStack(spacing: 24) {
                // Logo area
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("PIKTOR STUDIO")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.white)

                    Text("Pixel Art Studio")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "FFD700"))
                }
                .padding(.bottom, 8)

                // Form fields
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(PixelTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $password)
                        .textFieldStyle(PixelTextFieldStyle())
                        .textContentType(isSignUp ? .newPassword : .password)
                }

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Enter World button
                Button(action: authenticate) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        }
                        Text(isSignUp ? "CREATE ACCOUNT" : "ENTER WORLD")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

                // Toggle sign up / sign in
                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "FFD700"))
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "0D1117").opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "FFD700").opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        GeometryReader { geo in
            let halfW = geo.size.width / 2
            let halfH = geo.size.height / 2

            ZStack {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        quadrantColors[0].frame(width: halfW, height: halfH)
                        quadrantColors[1].frame(width: halfW, height: halfH)
                    }
                    HStack(spacing: 0) {
                        quadrantColors[2].frame(width: halfW, height: halfH)
                        quadrantColors[3].frame(width: halfW, height: halfH)
                    }
                }

                // Overlay grid pattern
                Canvas { context, size in
                    let gridSize: CGFloat = 20
                    for x in stride(from: 0, through: size.width, by: gridSize) {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
                    }
                    for y in stride(from: 0, through: size.height, by: gridSize) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Auth Action

    private func authenticate() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isSignUp {
                    try await supabaseManager.signUp(email: email, password: password, fullName: "")
                } else {
                    try await supabaseManager.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Custom TextField Style

struct PixelTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color(hex: "161B22"))
            .foregroundColor(.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "30363D"), lineWidth: 1)
            )
            .font(.system(size: 14, design: .monospaced))
    }
}

#Preview {
    LoginView()
        .environmentObject(SupabaseManager.shared)
}
