import SwiftUI

struct StatusBarView: View {
    let status: AppStatusViewModel.Status

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var dotColor: Color {
        switch status {
        case .ready: .green
        case .checking, .starting: .orange
        case .failed: .red
        case .idle: .gray
        }
    }

    private var label: String {
        switch status {
        case .idle: "Ollama: Idle"
        case .checking: "Checking…"
        case .starting: "Starting…"
        case .ready: "Ready"
        case .failed(let msg): "Error: \(msg)"
        }
    }
}
#Preview("StatusBarView - Ready") {
    StatusBarView(status: .ready)
        .frame(maxWidth: .infinity)
        .padding()
}

#Preview("StatusBarView - Checking") {
    StatusBarView(status: .checking)
        .frame(maxWidth: .infinity)
        .padding()
}

#Preview("StatusBarView - Failed") {
    StatusBarView(status: .failed("Connection refused"))
        .frame(maxWidth: .infinity)
        .padding()
}

