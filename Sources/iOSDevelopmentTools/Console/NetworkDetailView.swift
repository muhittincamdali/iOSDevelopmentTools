import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// One request: summary, timings, headers and bodies, with cURL and HAR export.
struct NetworkDetailView: View {
    let model: NetworkConsoleModel
    let id: NetworkEntry.ID

    var body: some View {
        if let entry = model.entries.first(where: { $0.id == id }) {
            NetworkEntryView(entry: entry)
        } else {
            ContentUnavailableView("Request Removed", systemImage: "trash", description: Text("The log was cleared or the request was dropped to make room."))
        }
    }
}

/// One request in detail: summary, headers, bodies and timings, with a menu to share it as a
/// cURL command or a HAR file. The console shows it when a request is selected; use it directly
/// to show a request somewhere else, inside a `NavigationStack`.
public struct NetworkEntryView: View {
    let entry: NetworkEntry

    /// Creates a detail view for the entry.
    public init(entry: NetworkEntry) {
        self.entry = entry
    }

    public var body: some View {
        Form {
            Section("Summary") {
                LabeledValue("URL", entry.url, monospaced: true)
                LabeledValue("Method", entry.method)
                LabeledValue("Status", statusText)
                LabeledValue("Started", entry.startDate.formatted(.dateTime.year().month().day().hour().minute().second()))
                LabeledValue("Duration", ConsoleFormat.duration(entry.duration))
                if let redirect = entry.redirectURL {
                    LabeledValue("Redirected to", redirect, monospaced: true)
                }
                if let error = entry.error {
                    LabeledValue("Error", "\(error.message) (\(error.domain) \(error.code))")
                }
            }
            HeadersSection(title: "Request Headers", headers: entry.requestHeaders)
            if let body = entry.requestBody {
                Section("Request Body") { BodyView(captured: body) }
            }
            HeadersSection(title: "Response Headers", headers: entry.responseHeaders)
            if let body = entry.responseBody {
                Section("Response Body") { BodyView(captured: body) }
            }
            if entry.timings != nil || entry.networkProtocol != nil {
                Section("Timings") {
                    if let networkProtocol = entry.networkProtocol {
                        LabeledValue("Protocol", networkProtocol)
                    }
                    if let timings = entry.timings {
                        timingRow("DNS", timings.domainLookup)
                        timingRow("Connect", timings.connect)
                        timingRow("TLS", timings.secureConnection)
                        timingRow("Send", timings.send)
                        timingRow("Wait", timings.wait)
                        timingRow("Receive", timings.receive)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(entry.path.isEmpty ? "/" : entry.path)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: entry.curlCommand(), preview: SharePreview("cURL command")) {
                        Label("Share as cURL", systemImage: "terminal")
                    }
                    ShareLink(item: HTTPArchiveFile(entries: [entry]), preview: SharePreview("Request (HAR)")) {
                        Label("Export HAR", systemImage: "doc")
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var statusText: String {
        switch entry.state {
        case .pending: return "Pending"
        case .failed: return entry.error?.isCancellation == true ? "Cancelled" : "Failed"
        case .completed:
            guard let status = entry.statusCode else { return "Completed" }
            let phrase = HTTPArchive.reasonPhrase(status)
            return phrase.isEmpty ? "\(status)" : "\(status) \(phrase)"
        }
    }

    @ViewBuilder
    private func timingRow(_ label: String, _ value: TimeInterval?) -> some View {
        if let value {
            LabeledValue(label, ConsoleFormat.duration(value))
        }
    }
}

/// A label with selectable text below or beside it.
struct LabeledValue: View {
    let label: String
    let value: String
    let monospaced: Bool

    init(_ label: String, _ value: String, monospaced: Bool = false) {
        self.label = label
        self.value = value
        self.monospaced = monospaced
    }

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .font(monospaced ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct HeadersSection: View {
    let title: String
    let headers: [HTTPHeader]

    var body: some View {
        if !headers.isEmpty {
            Section(title) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(header.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(header.value)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

/// A stored body as formatted JSON, text or a size, with notes about truncation and redaction.
struct BodyView: View {
    /// Longer bodies are shown cut off: a `Text` this long is already slow to lay out.
    static let displayLimit = 100_000

    let captured: CapturedBody

    var body: some View {
        if captured.redaction == .withheld {
            note("Withheld: the body looked structured but could not be checked for sensitive values, so it was not stored.", systemImage: "eye.slash")
        } else if let text = captured.prettyPrintedJSON ?? captured.text {
            let shown = text.count > Self.displayLimit ? String(text.prefix(Self.displayLimit)) : text
            Text(shown)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if shown.count < text.count {
                note("Showing the first \(Self.displayLimit.formatted()) characters.", systemImage: "scissors")
            }
        } else {
            note("Binary data, \(ConsoleFormat.bytes(captured.byteCount)).", systemImage: "doc.zipper")
        }
        if captured.isTruncated && captured.redaction != .withheld {
            note("Stored \(ConsoleFormat.bytes(captured.data.count)) of \(ConsoleFormat.bytes(captured.byteCount)).", systemImage: "scissors")
        }
        if captured.redaction == .redacted {
            note("Sensitive values were replaced with \(RedactionPolicy.replacement).", systemImage: "lock")
        }
    }

    private func note(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// Entries as a `.har` file for `ShareLink`.
struct HTTPArchiveFile: Transferable {
    let entries: [NetworkEntry]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            try HTTPArchive(entries: file.entries).jsonData()
        }
        .suggestedFileName("network.har")
    }
}
