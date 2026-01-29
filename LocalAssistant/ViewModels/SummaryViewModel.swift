import Foundation
import Observation

@MainActor
@Observable
final class SummaryViewModel {
    private(set) var summary: String = ""
    private(set) var isGenerating = false

    private let service: SummarizationService

    init(service: SummarizationService) {
        self.service = service
        self.summary = service.loadSummary()
    }

    func reload() {
        summary = service.loadSummary()
    }

    func regenerate(messages: [ChatMessage]) async {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let result = try await service.generateSummary(from: messages)
            summary = result
            service.saveSummary(result)
        } catch {
            // Keep existing summary on failure
        }
    }

    func clear() {
        summary = ""
        service.clearSummary()
    }
}
