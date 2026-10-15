import SwiftUI

/// The Network tab: recorded requests, newest first, with search, an outcome filter and export.
struct NetworkListView: View {
    @Bindable var model: NetworkConsoleModel
    @Environment(\.consoleShowsDoneButton) private var showsDoneButton
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let entries = model.visibleEntries
        List {
            ForEach(entries) { entry in
                NavigationLink(value: entry.id) {
                    NetworkRow(entry: entry)
                }
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    model.entries.isEmpty ? "No Requests" : "No Matches",
                    systemImage: "network",
                    description: Text(model.entries.isEmpty
                        ? "Requests appear here as the app makes them."
                        : "No request matches the search and filter."))
            }
        }
        .navigationTitle("Network")
        .navigationDestination(for: NetworkEntry.ID.self) { id in
            NetworkDetailView(model: model, id: id)
        }
        .searchable(text: $model.filter.text, prompt: "URL, method or status")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Show", selection: $model.filter.outcome) {
                        ForEach(NetworkFilter.Outcome.allCases) { outcome in
                            Text(outcome.title).tag(outcome)
                        }
                    }
                    Divider()
                    ShareLink(
                        item: HTTPArchiveFile(entries: model.entries.filter(model.filter.matches)),
                        preview: SharePreview("Network requests (HAR)")
                    ) {
                        Label("Export HAR", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                    Button(role: .destructive) {
                        model.clear()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(model.entries.isEmpty)
                } label: {
                    Label("Options", systemImage: model.filter.outcome == .all
                        ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
    }
}

/// One request in the list: method, status, timing and size above the host and path.
struct NetworkRow: View {
    let entry: NetworkEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.method)
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(ConsoleStyle.color(for: entry))
                Text(statusText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(ConsoleStyle.color(for: entry))
                Text(detailText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(entry.startDate, format: .dateTime.hour().minute().second())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(entry.path.isEmpty ? "/" : entry.path)
                .font(.callout.monospaced())
                .lineLimit(2)
                .truncationMode(.middle)
            if let host = entry.host {
                Text(host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        switch entry.state {
        case .pending: "…"
        case .failed: entry.error?.isCancellation == true ? "Cancelled" : "Failed"
        case .completed: entry.statusCode.map(String.init) ?? "Done"
        }
    }

    private var detailText: String {
        var parts = [ConsoleFormat.duration(entry.duration)]
        if let body = entry.responseBody {
            parts.append(ConsoleFormat.bytes(body.byteCount))
        }
        return parts.joined(separator: " · ")
    }
}
