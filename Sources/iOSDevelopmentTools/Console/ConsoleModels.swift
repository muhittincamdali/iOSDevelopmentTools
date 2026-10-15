import Foundation
import Observation

/// Keeps a copy of a logger's entries for SwiftUI, refreshed when the logger changes.
@MainActor
@Observable
final class NetworkConsoleModel {
    let logger: NetworkLogger
    private(set) var entries: [NetworkEntry] = []
    var filter = NetworkFilter()

    init(logger: NetworkLogger) {
        self.logger = logger
        entries = logger.entries
    }

    /// Newest first, filtered.
    var visibleEntries: [NetworkEntry] {
        entries.reversed().filter(filter.matches)
    }

    /// Follows the logger until the calling task is cancelled. At most about seven refreshes a
    /// second, however fast requests arrive.
    func follow() async {
        refresh()
        for await _ in logger.changes() {
            refresh()
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    func refresh() {
        entries = logger.entries
    }

    func clear() {
        logger.clear()
        refresh()
    }
}

/// Keeps a copy of a log store's entries for SwiftUI, refreshed when the store changes.
@MainActor
@Observable
final class LogConsoleModel {
    let store: LogStore
    private(set) var entries: [LogEntry] = []
    var filter = LogFilter()

    init(store: LogStore) {
        self.store = store
        entries = store.entries
    }

    /// Newest first, filtered.
    var visibleEntries: [LogEntry] {
        entries.reversed().filter(filter.matches)
    }

    var categories: [String] {
        Set(entries.map(\.category)).sorted()
    }

    func follow() async {
        refresh()
        for await _ in store.changes() {
            refresh()
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    func refresh() {
        entries = store.entries
    }

    func clear() {
        store.clear()
        refresh()
    }

    /// The visible messages as text, oldest first.
    var exportText: String {
        entries.filter(filter.matches).map(\.formatted).joined(separator: "\n")
    }
}
