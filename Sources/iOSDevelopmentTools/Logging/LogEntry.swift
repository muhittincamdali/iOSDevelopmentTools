import Foundation
import os

/// How important a log message is, from ``debug`` to ``fault``.
public enum LogLevel: Int, Sendable, Hashable, Comparable, CaseIterable, Codable {
    /// Detail for debugging, usually switched off with ``LogStore/Configuration/minimumLevel``.
    case debug
    /// Something that happened as expected.
    case info
    /// Something worth noticing, such as a configuration change.
    case notice
    /// Something unexpected that the app recovered from.
    case warning
    /// An operation failed.
    case error
    /// A bug or a state the app should never be in.
    case fault

    /// Orders levels from ``debug`` (lowest) to ``fault`` (highest).
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// A short uppercase name, such as `WARNING`.
    public var label: String {
        switch self {
        case .debug: "DEBUG"
        case .info: "INFO"
        case .notice: "NOTICE"
        case .warning: "WARNING"
        case .error: "ERROR"
        case .fault: "FAULT"
        }
    }

    /// The matching unified logging type. `notice` and `warning` both map to `.default`.
    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .notice, .warning: .default
        case .error: .error
        case .fault: .fault
        }
    }
}

/// One message in a ``LogStore``.
public struct LogEntry: Sendable, Identifiable, Hashable {
    /// A unique identifier for the message.
    public let id: UUID
    /// When the message was logged.
    public let date: Date
    /// How important the message is.
    public let level: LogLevel
    /// The category it was logged under, such as `network` or `checkout`.
    public let category: String
    /// The message, redacted and cut off at ``LogStore/Configuration/maximumMessageLength``
    /// Unicode scalars.
    public let message: String
    /// Whether the message was longer than the limit and was cut off.
    public let isTruncated: Bool
    /// The file that logged it, as `#fileID` (`Module/File.swift`).
    public let file: String
    /// The function that logged it.
    public let function: String
    /// The line that logged it.
    public let line: Int

    /// Creates an entry. ``LogStore`` creates entries for you; this is for previews and tests.
    public init(
        id: UUID = UUID(), date: Date, level: LogLevel, category: String, message: String,
        isTruncated: Bool = false, file: String, function: String, line: Int
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.category = category
        self.message = message
        self.isTruncated = isTruncated
        self.file = file
        self.function = function
        self.line = line
    }

    /// One line of text: time (UTC), level, category, message and source location.
    public var formatted: String {
        let time = date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        return "\(time) [\(level.label)] [\(category)] \(message) (\(fileName):\(line))"
    }
}

/// Which log entries to show.
public struct LogFilter: Sendable, Hashable {
    /// Entries below this level are hidden.
    public var minimumLevel: LogLevel
    /// Only these categories are shown; an empty set shows all of them.
    public var categories: Set<String>
    /// Text that the message, category or file must contain, ignoring case and diacritics.
    /// Leading and trailing spaces are ignored; an empty text matches everything.
    public var text: String

    /// Creates a filter. The defaults show every message.
    public init(minimumLevel: LogLevel = .debug, categories: Set<String> = [], text: String = "") {
        self.minimumLevel = minimumLevel
        self.categories = categories
        self.text = text
    }

    /// Whether the entry passes the filter.
    public func matches(_ entry: LogEntry) -> Bool {
        guard entry.level >= minimumLevel else { return false }
        guard categories.isEmpty || categories.contains(entry.category) else { return false }
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        return [entry.message, entry.category, entry.file].contains {
            $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
