import SwiftUI

/// Renders search sources as overlapping favicon avatars with "Sources" label
struct SearchSourcesView: View {
    let sources: [(domain: String, url: String)]
    private let maxVisibleFavicons = 5
    private let faviconSize: CGFloat = 20
    private let overlapAmount: CGFloat = -8

    @State private var faviconCache: [String: NSImage] = [:]

    var body: some View {
        HStack(spacing: 8) {
            // Overlapping favicon stack
            HStack(spacing: overlapAmount) {
                ForEach(Array(visibleSources.enumerated()), id: \.offset) { index, source in
                    FaviconCircle(
                        domain: source.domain,
                        url: source.url,
                        favicon: faviconCache[source.domain],
                        size: faviconSize
                    )
                    .zIndex(Double(visibleSources.count - index))
                    .task {
                        if faviconCache[source.domain] == nil {
                            await loadFavicon(for: source.domain)
                        }
                    }
                }

                // Overflow badge (+N)
                if hiddenCount > 0 {
                    OverflowBadge(count: hiddenCount, size: faviconSize)
                        .zIndex(0)
                }
            }

            // "Sources" label
            Text("Sources")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visibleSources: [(domain: String, url: String)] {
        Array(sources.prefix(maxVisibleFavicons))
    }

    private var hiddenCount: Int {
        max(0, sources.count - maxVisibleFavicons)
    }

    private func loadFavicon(for domain: String) async {
        // Use Google's favicon service
        let faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=32"

        guard let url = URL(string: faviconURL),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else {
            return
        }

        await MainActor.run {
            faviconCache[domain] = image
        }
    }
}

/// Individual circular favicon button
struct FaviconCircle: View {
    let domain: String
    let url: String
    let favicon: NSImage?
    let size: CGFloat

    @State private var isHovered = false

    var body: some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: size, height: size)

                // Favicon or placeholder
                Group {
                    if let favicon = favicon {
                        Image(nsImage: favicon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: size * 0.7, height: size * 0.7)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: size * 0.5))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Border
                Circle()
                    .strokeBorder(
                        isHovered
                            ? Color.accentColor.opacity(0.6)
                            : Color(nsColor: .separatorColor),
                        lineWidth: isHovered ? 2 : 1.5
                    )
                    .frame(width: size, height: size)
            }
        }
        .buttonStyle(.plain)
        .help(simplifiedDomainName(domain))
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private func simplifiedDomainName(_ domain: String) -> String {
        // Remove www. prefix
        var cleaned = domain.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)

        // Remove TLD (.com, .org, etc.)
        if let lastDot = cleaned.lastIndex(of: ".") {
            cleaned = String(cleaned[..<lastDot])
        }

        // Replace dots/hyphens with spaces and title case
        let words = cleaned
            .replacingOccurrences(of: "[.-]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }

        return words.joined(separator: " ")
    }
}

/// +N overflow badge
struct OverflowBadge: View {
    let count: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: size, height: size)

            Text("+\(count)")
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.secondary)

            Circle()
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1.5)
                .frame(width: size, height: size)
        }
    }
}

#Preview("Search Sources - Few") {
    SearchSourcesView(sources: [
        ("developer.apple.com", "https://developer.apple.com/swift"),
        ("github.com", "https://github.com/apple/swift"),
        ("stackoverflow.com", "https://stackoverflow.com/questions/tagged/swift")
    ])
    .padding()
    .frame(width: 400)
}

#Preview("Search Sources - Many") {
    SearchSourcesView(sources: [
        ("developer.apple.com", "https://developer.apple.com/swift"),
        ("github.com", "https://github.com/apple/swift"),
        ("stackoverflow.com", "https://stackoverflow.com/questions/tagged/swift"),
        ("hackingwithswift.com", "https://www.hackingwithswift.com"),
        ("swift.org", "https://swift.org"),
        ("swiftbysundell.com", "https://swiftbysundell.com"),
        ("raywenderlich.com", "https://www.raywenderlich.com"),
        ("medium.com", "https://medium.com/tag/swift")
    ])
    .padding()
    .frame(width: 400)
}
