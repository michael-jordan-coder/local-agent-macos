import Foundation
import os

private let log = Logger(subsystem: "daniels.LocalAssistant", category: "OllamaClient")

struct OllamaModel: Codable, Identifiable, Hashable {
    let name: String
    var id: String { name }
}

struct OllamaClient {
    private let baseURL = "http://127.0.0.1:11434"

    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config)
    }()

    /// Lists locally available models.
    func fetchModels() async throws -> [OllamaModel] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return [] }
        let (data, _) = try await session.data(from: url)

        struct ModelResponse: Decodable {
            let models: [OllamaModel]
        }

        return try JSONDecoder().decode(ModelResponse.self, from: data).models
    }

    /// Non-streaming generate (used by summarization).
    func generate(prompt: String, model: String = "gpt-oss:20b-cloud") async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)

        struct Response: Decodable { let response: String }
        return try JSONDecoder().decode(Response.self, from: data).response
    }

    /// Streaming generate – calls `onToken` for each chunk on MainActor.
    func streamGenerate(prompt: String, model: String = "gpt-oss:20b-cloud", images: [String]? = nil, onToken: @escaping @MainActor (String) -> Void) async throws {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        var body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true
        ]

        if let images, !images.isEmpty {
            body["images"] = images
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, _) = try await session.bytes(for: request)

        struct Chunk: Decodable {
            let response: String
            let done: Bool?
        }

        for try await line in bytes.lines {
            if Task.isCancelled {
                log.info("Stream cancelled, breaking out of line loop")
                throw CancellationError()
            }
            guard let data = line.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
            await onToken(chunk.response)
            if chunk.done == true { return }
        }
    }

    func isReachable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
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
