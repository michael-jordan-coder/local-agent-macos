import Foundation
import Observation

@Observable
final class AppStatusViewModel {
    enum Status: Equatable {
        case idle, checking, starting, ready
        case failed(String)
    }

    private(set) var status: Status = .idle

    var isReady: Bool { status == .ready }

    private let client: OllamaClient

    init(client: OllamaClient) {
        self.client = client
    }

    func ensureRunning() async {
        status = .checking

        if await client.isReachable() {
            status = .ready
            return
        }

        status = .starting
        client.launchProcess()

        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(400))
            if await client.isReachable() {
                status = .ready
                return
            }
        }

        status = .failed("Could not start Ollama. Make sure it is installed.")
    }
}
