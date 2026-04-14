import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BlogView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager

    @State private var posts: [BlogPost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading posts...")
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { loadPosts() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 60)
                } else if posts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "book")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No blog posts yet")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(posts) { post in
                            BlogPostCard(post: post)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(hex: "0D1117"))
            .navigationTitle("Blog")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { loadPosts() }
            .onAppear { loadPosts() }
        }
    }

    // MARK: - Load Posts

    private func loadPosts() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                posts = try await supabaseManager.fetchBlogPosts()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Blog Post Card

struct BlogPostCard: View {
    let post: BlogPost

    var body: some View {
        Button(action: openInSafari) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover image
                if let urlString = post.coverImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipped()
                        case .failure:
                            coverPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 160)
                                .background(Color(hex: "21262D"))
                        @unknown default:
                            coverPlaceholder
                        }
                    }
                } else {
                    coverPlaceholder
                }

                // Content
                VStack(alignment: .leading, spacing: 10) {
                    // Title
                    Text(post.title)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Excerpt
                    Text(post.excerpt)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Tags + Date row
                    HStack {
                        // Tags
                        HStack(spacing: 6) {
                            ForEach(post.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(tagColor(for: tag))
                                    .cornerRadius(10)
                            }
                        }

                        Spacer()

                        // Date
                        if let dateString = post.createdAt {
                            Text(formattedDate(dateString))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "161B22"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "30363D"), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cover Placeholder

    private var coverPlaceholder: some View {
        ZStack {
            Color(hex: "21262D")
            Image(systemName: "book.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    // MARK: - Helpers

    private func tagColor(for tag: String) -> Color {
        switch tag.lowercased() {
        case "tutorial": return .blue
        case "tips": return .green
        case "inspiration": return .purple
        case "game-dev": return .orange
        case "news": return .red
        case "community": return .cyan
        default: return Color(hex: "FFD700")
        }
    }

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        return isoString
    }

    private func openInSafari() {
        guard let url = URL(string: "https://piktor.studio/blog/\(post.slug)") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    BlogView()
        .environmentObject(SupabaseManager.shared)
}
