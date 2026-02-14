import Foundation

struct SearchService {
    private let session: URLSession
    private let maxResults = 7

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Searches DuckDuckGo and returns structured results
    func search(query: String) async throws -> SearchResponse {
        // Build DuckDuckGo HTML search URL
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            throw SearchError.invalidQuery
        }

        // Fetch page with URLSession
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SearchError.networkError
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw SearchError.decodingError
        }

        // Parse HTML for search results
        let results = parseResults(from: html)

        // Format as structured text for LLM
        let formattedResults = formatResults(results, query: query)

        return SearchResponse(
            query: query,
            results: results,
            formattedResults: formattedResults
        )
    }

    private func parseResults(from html: String) -> [SearchResult] {
        var results: [SearchResult] = []

        // DuckDuckGo HTML structure:
        // <div class="result results_links results_links_deep web-result">
        //   <div class="links_main links_deep result__body">
        //     <h2 class="result__title">
        //       <a rel="nofollow" class="result__a" href="...">Title</a>
        //     </h2>
        //     <a class="result__snippet" href="...">Snippet text...</a>
        //   </div>
        // </div>

        // Simple regex-based extraction (no external dependencies)
        let resultPattern = #"<div class="result[^"]*"[^>]*>(.*?)</div>\s*</div>\s*</div>"#
        let titlePattern = #"<h2[^>]*>.*?<a[^>]*>(.*?)</a>"#
        let snippetPattern = #"<a class="result__snippet"[^>]*>(.*?)</a>"#
        let urlPattern = #"<a rel="nofollow" class="result__a" href="(.*?)">"#

        guard let resultRegex = try? NSRegularExpression(pattern: resultPattern, options: [.dotMatchesLineSeparators]),
              let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: [.dotMatchesLineSeparators]),
              let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: [.dotMatchesLineSeparators]),
              let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: []) else {
            return results
        }

        let nsHtml = html as NSString
        let matches = resultRegex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))

        for match in matches.prefix(maxResults) {
            let resultBlock = nsHtml.substring(with: match.range(at: 1))
            let nsResultBlock = resultBlock as NSString

            // Extract title
            var title = ""
            if let titleMatch = titleRegex.firstMatch(in: resultBlock, range: NSRange(location: 0, length: nsResultBlock.length)) {
                title = nsResultBlock.substring(with: titleMatch.range(at: 1))
                    .stripHTML()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Extract snippet
            var snippet = ""
            if let snippetMatch = snippetRegex.firstMatch(in: resultBlock, range: NSRange(location: 0, length: nsResultBlock.length)) {
                snippet = nsResultBlock.substring(with: snippetMatch.range(at: 1))
                    .stripHTML()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Extract URL
            var urlString = ""
            if let urlMatch = urlRegex.firstMatch(in: resultBlock, range: NSRange(location: 0, length: nsResultBlock.length)) {
                urlString = nsResultBlock.substring(with: urlMatch.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if !title.isEmpty && !snippet.isEmpty {
                results.append(SearchResult(title: title, snippet: snippet, url: urlString))
            }
        }

        return results
    }

    private func formatResults(_ results: [SearchResult], query: String) -> String {
        guard !results.isEmpty else {
            return "No search results found for \"\(query)\"."
        }

        var formatted = "Search results for \"\(query)\":\n\n"

        for (index, result) in results.enumerated() {
            formatted += "\(index + 1). \(result.title)\n"
            formatted += "   \(result.snippet)\n"
            if !result.url.isEmpty {
                formatted += "   \(result.url)\n"
            }
            formatted += "\n"
        }

        return formatted
    }
}

// MARK: - Supporting Types

struct SearchResult {
    let title: String
    let snippet: String
    let url: String
}

struct SearchResponse {
    let query: String
    let results: [SearchResult]
    let formattedResults: String

    /// Extract unique domains from search results for display
    var sourceDomains: [(domain: String, url: String)] {
        var seen = Set<String>()
        var domains: [(String, String)] = []

        for result in results {
            guard let url = URL(string: result.url),
                  let host = url.host else { continue }

            let domain = host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)

            if !seen.contains(domain) {
                seen.insert(domain)
                domains.append((domain, result.url))
            }
        }

        return domains
    }
}

enum SearchError: LocalizedError {
    case invalidQuery
    case networkError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .networkError:
            return "Network request failed"
        case .decodingError:
            return "Failed to decode search results"
        }
    }
}

// MARK: - HTML Helper

private extension String {
    func stripHTML() -> String {
        // Remove HTML tags
        var result = self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")

        return result
    }
}
