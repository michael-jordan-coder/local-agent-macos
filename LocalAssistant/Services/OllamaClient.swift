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

    private func logRequestStart(method: String, path: String, source: String) -> Date {
        let start = Date()
        log.info("REQ start method=\(method, privacy: .public) path=\(path, privacy: .public) source=\(source, privacy: .public) pid=\(ProcessInfo.processInfo.processIdentifier) mainThread=\(Thread.isMainThread)")
        return start
    }

    private func logRequestEnd(
        method: String,
        path: String,
        source: String,
        start: Date,
        statusCode: Int?,
        bytes: Int,
        error: Error? = nil
    ) {
        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        if let error {
            log.error("REQ fail method=\(method, privacy: .public) path=\(path, privacy: .public) source=\(source, privacy: .public) elapsedMs=\(elapsedMs) error=\(error.localizedDescription, privacy: .public)")
            return
        }
        log.info("REQ end method=\(method, privacy: .public) path=\(path, privacy: .public) source=\(source, privacy: .public) status=\(statusCode ?? -1) bytes=\(bytes) elapsedMs=\(elapsedMs)")
    }

    /// Lists locally available models.
    func fetchModels(source: String = "unspecified") async throws -> [OllamaModel] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return [] }
        let start = logRequestStart(method: "GET", path: "/api/tags", source: source)
        do {
            let (data, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode
            logRequestEnd(
                method: "GET",
                path: "/api/tags",
                source: source,
                start: start,
                statusCode: status,
                bytes: data.count
            )

            struct ModelResponse: Decodable {
                let models: [OllamaModel]
            }

            return try JSONDecoder().decode(ModelResponse.self, from: data).models
        } catch {
            logRequestEnd(
                method: "GET",
                path: "/api/tags",
                source: source,
                start: start,
                statusCode: nil,
                bytes: 0,
                error: error
            )
            throw error
        }
    }

    /// Non-streaming generate (used by summarization).
    func generate(
        prompt: String,
        model: String = "gpt-oss:20b-cloud",
        source: String = "unspecified"
    ) async throws -> String {
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

        let start = logRequestStart(method: "POST", path: "/api/generate", source: source)
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode
            logRequestEnd(
                method: "POST",
                path: "/api/generate",
                source: source,
                start: start,
                statusCode: status,
                bytes: data.count
            )

            struct Response: Decodable { let response: String }
            return try JSONDecoder().decode(Response.self, from: data).response
        } catch {
            logRequestEnd(
                method: "POST",
                path: "/api/generate",
                source: source,
                start: start,
                statusCode: nil,
                bytes: 0,
                error: error
            )
            throw error
        }
    }

    /// Streaming generate – calls `onToken` for each chunk on MainActor.
    func streamGenerate(
        prompt: String,
        model: String = "gpt-oss:20b-cloud",
        images: [String]? = nil,
        source: String = "unspecified",
        onToken: @escaping @MainActor (String) -> Void
    ) async throws {
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

        let start = logRequestStart(method: "POST", path: "/api/generate(stream)", source: source)
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            logRequestEnd(
                method: "POST",
                path: "/api/generate(stream)",
                source: source,
                start: start,
                statusCode: nil,
                bytes: 0,
                error: error
            )
            throw error
        }

        struct Chunk: Decodable {
            let response: String
            let done: Bool?
        }

        var streamedBytes = 0
        let status = (response as? HTTPURLResponse)?.statusCode

        do {
            for try await line in bytes.lines {
                if Task.isCancelled {
                    log.info("Stream cancelled, breaking out of line loop")
                    throw CancellationError()
                }
                streamedBytes += line.utf8.count
                guard let data = line.data(using: .utf8),
                      let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
                await onToken(chunk.response)
                if chunk.done == true {
                    logRequestEnd(
                        method: "POST",
                        path: "/api/generate(stream)",
                        source: source,
                        start: start,
                        statusCode: status,
                        bytes: streamedBytes
                    )
                    return
                }
            }
        } catch {
            logRequestEnd(
                method: "POST",
                path: "/api/generate(stream)",
                source: source,
                start: start,
                statusCode: status,
                bytes: streamedBytes,
                error: error
            )
            throw error
        }

        logRequestEnd(
            method: "POST",
            path: "/api/generate(stream)",
            source: source,
            start: start,
            statusCode: status,
            bytes: streamedBytes
        )
    }

    func isReachable(source: String = "unspecified") async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        let start = logRequestStart(method: "GET", path: "/api/tags", source: source)
        do {
            let (data, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode
            logRequestEnd(
                method: "GET",
                path: "/api/tags",
                source: source,
                start: start,
                statusCode: status,
                bytes: data.count
            )
            return status == 200
        } catch {
            logRequestEnd(
                method: "GET",
                path: "/api/tags",
                source: source,
                start: start,
                statusCode: nil,
                bytes: 0,
                error: error
            )
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
                log.info("Launched ollama process path=\(path, privacy: .public) pid=\(process.processIdentifier)")
                return
            } catch {
                log.error("Failed to launch candidate path=\(path, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                continue
            }
        }
        log.error("Failed to launch ollama process from all candidates")
    }
}
