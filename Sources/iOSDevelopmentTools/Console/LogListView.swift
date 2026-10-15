import SwiftUI

/// The Logs tab: messages newest first, with search, a level and category filter and export.
struct LogListView: View {
    @Bindable var model: LogConsoleModel
    @Environment(\.consoleShowsDoneButton) private var showsDoneButton
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let entries = model.visibleEntries
        List(entries) { entry in
            LogRow(entry: entry)
                .contextMenu {
                    Button {
                        Clipboard.copy(entry.formatted)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    model.entries.isEmpty ? "No Messages" : "No Matches",
                    systemImage: "text.alignleft",
                    description: Text(model.entries.isEmpty
                        ? "Messages logged with LogStore appear here."
                        : "No message matches the search and filter."))
            }
        }
        .navigationTitle("Logs")
        .searchable(text: $model.filter.text, prompt: "Message, category or file")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Minimum level", selection: $model.filter.minimumLevel) {
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            Text(level.label.capitalized).tag(level)
                        }
                    }
                    if !model.categories.isEmpty {
                        Menu("Categories") {
                            Button("All") { model.filter.categories = [] }
                            ForEach(model.categories, id: \.self) { category in
                                Toggle(category, isOn: categoryBinding(category))
                            }
                        }
                    }
                    Divider()
                    ShareLink(item: model.exportText, preview: SharePreview("Log messages")) {
                        Label("Export Text", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                    Button(role: .destructive) {
                        model.clear()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(model.entries.isEmpty)
                } label: {
                    Label("Options", systemImage: isFiltered
                        ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private var isFiltered: Bool {
        model.filter.minimumLevel != .debug || !model.filter.categories.isEmpty
    }

    private func categoryBinding(_ category: String) -> Binding<Bool> {
        Binding {
            model.filter.categories.contains(category)
        } set: { isOn in
            if isOn {
                model.filter.categories.insert(category)
            } else {
                model.filter.categories.remove(category)
            }
        }
    }
}

/// One message: level, time, category and source location above the text.
struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: Self.symbol(for: entry.level))
                    .foregroundStyle(ConsoleStyle.color(for: entry.level))
                    .accessibilityLabel(entry.level.label.capitalized)
                Text(entry.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(entry.date, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(entry.message)
                .font(.callout)
                .lineLimit(6)
                .textSelection(.enabled)
            Text("\(entry.file.split(separator: "/").last.map(String.init) ?? entry.file):\(entry.line)")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    static func symbol(for level: LogLevel) -> String {
        switch level {
        case .debug: "ant"
        case .info: "info.circle"
        case .notice: "bell"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        case .fault: "bolt.trianglebadge.exclamationmark"
        }
    }
}

/// The Device tab: a ``DeviceSnapshot`` that can be refreshed and shared.
struct DeviceView: View {
    @State private var snapshot = DeviceSnapshot.current()
    @Environment(\.consoleShowsDoneButton) private var showsDoneButton
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                ForEach(snapshot.rows()) { row in
                    LabeledValue(row.label, row.value)
                }
            } footer: {
                Text("Taken \(snapshot.date.formatted(date: .omitted, time: .standard))")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Device")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: snapshot.report(), preview: SharePreview("Device report")) {
                    Label("Share Report", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    snapshot = DeviceSnapshot.current()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

extension EnvironmentValues {
    /// Whether the console is presented in a sheet and its tabs show a Done button.
    @Entry var consoleShowsDoneButton = false
}

/// Puts text on the system pasteboard.
enum Clipboard {
    @MainActor
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
