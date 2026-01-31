import Foundation

struct OllamaClient {
    private let baseURL = "http://127.0.0.1:11434"

    /// Non-streaming generate (used by summarization).
    func generate(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": "llama3",
            "prompt": prompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Decodable { let response: String }
        return try JSONDecoder().decode(Response.self, from: data).response
    }

    /// Streaming generate – calls `onToken` for each chunk on MainActor.
    func streamGenerate(prompt: String, images: [Data]? = nil, onToken: @escaping @MainActor (String) -> Void) async throws {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "model": "llama3",
            "prompt": prompt,
            "stream": true
        ]
        
        if let images = images, !images.isEmpty {
            body["images"] = images.map { $0.base64EncodedString() }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Use a dedicated session so we can invalidate it to force-close the connection.
        let session = URLSession(configuration: .default)
        defer { session.invalidateAndCancel() }

        let (bytes, _) = try await session.bytes(for: request)

        struct Chunk: Decodable {
            let response: String
            let done: Bool?
        }

        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
            await onToken(chunk.response)
            if chunk.done == true { return }
        }
    }

    func isReachable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func launchProcess() {
        let candidates: [(String, [String])] = [
            ("/usr/local/bin/ollama", ["serve"]),
            ("/opt/homebrew/bin/ollama", ["serve"]),
            ("/usr/bin/env", ["ollama", "serve"])
        ]
        for (path, args) in candidates {
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                return
            } catch {
                continue
            }
        }
    }
}
