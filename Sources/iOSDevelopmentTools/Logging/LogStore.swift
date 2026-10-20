import Foundation
import os

/// Keeps the app's recent log messages in memory so they can be read in the console, and passes
/// them on to the unified logging system (Console.app, `log stream`, Xcode).
///
/// ```swift
/// LogStore.shared.info("Signed in", category: "auth")
/// LogStore.shared.error("Payment failed: \(error)", category: "checkout")
/// ```
///
/// Messages go through ``Configuration/redaction`` (see ``RedactionPolicy/redact(text:)``) before
/// they are kept or passed on: from the first secret name or other trigger in a message, the rest
/// of the message is hidden. That is a safety net: do not log secrets in the first place.
///
/// The store keeps at most ``Configuration/maximumEntries`` messages of at most
/// ``Configuration/maximumMessageLength`` Unicode scalars, so its memory use has a fixed upper
/// bound.
/// All methods can be called from any thread.
public final class LogStore: Sendable {
    /// What a store keeps.
    public struct Configuration: Sendable, Hashable {
        /// The largest value ``maximumEntries`` accepts.
        public static let entryLimit = 100_000
        /// The largest value ``maximumMessageLength`` accepts.
        public static let messageLengthLimit = 65_536

        private var storedMaximumEntries: Int
        private var storedMaximumMessageLength: Int

        /// How many messages are kept; the oldest is dropped when a new one would exceed it.
        /// Kept between 1 and ``entryLimit``.
        public var maximumEntries: Int {
            get { storedMaximumEntries }
            set { storedMaximumEntries = min(max(newValue, 1), Self.entryLimit) }
        }

        /// How many Unicode scalars (code points) of a message are kept, at most four UTF-8 bytes
        /// each. Kept between 1 and ``messageLengthLimit``.
        ///
        /// The limit counts scalars, not `Character`s: one `Character` can hold any number of
        /// combining marks, so a limit in `Character`s would not bound the memory a message uses.
        public var maximumMessageLength: Int {
            get { storedMaximumMessageLength }
            set { storedMaximumMessageLength = min(max(newValue, 1), Self.messageLengthLimit) }
        }

        /// Messages below this level are dropped.
        public var minimumLevel: LogLevel

        /// What is replaced in a message before it is kept or passed to unified logging.
        public var redaction: RedactionPolicy

        /// The subsystem for the unified logging system, or `nil` to keep messages in the store only.
        /// Messages are logged with private visibility, as unified logging does by default.
        public var systemLogSubsystem: String?

        /// Creates a configuration. Out-of-range limits are clamped.
        public init(
            maximumEntries: Int = 2_000,
            maximumMessageLength: Int = 4_096,
            minimumLevel: LogLevel = .debug,
            systemLogSubsystem: String? = Bundle.main.bundleIdentifier ?? "iOSDevelopmentTools",
            redaction: RedactionPolicy = .default
        ) {
            storedMaximumEntries = min(max(maximumEntries, 1), Self.entryLimit)
            storedMaximumMessageLength = min(max(maximumMessageLength, 1), Self.messageLengthLimit)
            self.minimumLevel = minimumLevel
            self.systemLogSubsystem = systemLogSubsystem
            self.redaction = redaction
        }
    }

    /// The longest category name, in Unicode scalars, that is kept; longer names are cut off.
    static let maximumCategoryLength = 64
    /// How many `os.Logger` instances are cached, one per category.
    static let systemLoggerCacheLimit = 64

    private struct State: Sendable {
        var configuration: Configuration
        var entries: BoundedBuffer<LogEntry>
        var observers: [UUID: AsyncStream<Void>.Continuation] = [:]
        var systemLoggers: [String: Logger] = [:]
    }

    /// The store most apps use.
    public static let shared = LogStore()

    private let state: OSAllocatedUnfairLock<State>

    /// Creates an empty store.
    public init(configuration: Configuration = Configuration()) {
        state = OSAllocatedUnfairLock(initialState: State(
            configuration: configuration, entries: BoundedBuffer(capacity: configuration.maximumEntries)))
    }

    /// What the store keeps. Lowering ``Configuration/maximumEntries`` drops the oldest messages.
    public var configuration: Configuration {
        get { state.withLock { $0.configuration } }
        set {
            mutate { state in
                state.configuration = newValue
                state.systemLoggers.removeAll()
                state.entries.setCapacity(newValue.maximumEntries)
            }
        }
    }

    /// The kept messages, oldest first.
    public var entries: [LogEntry] {
        state.withLock { $0.entries.elements }
    }

    /// The kept messages that pass the filter, oldest first.
    public func entries(matching filter: LogFilter) -> [LogEntry] {
        entries.filter(filter.matches)
    }

    /// The category names of the kept messages, sorted.
    public var categories: [String] {
        Set(entries.map(\.category)).sorted()
    }

    /// Removes every message.
    public func clear() {
        mutate { $0.entries.removeAll() }
    }

    /// A stream that yields whenever messages are added or removed. Bursts are coalesced into one
    /// element, and the stream ends when the task that iterates it is cancelled.
    public func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        state.withLock { $0.observers[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            _ = self?.state.withLock { $0.observers.removeValue(forKey: id) }
        }
        return stream
    }

    /// Logs a message. The message is built only when its level is kept, then redacted, then cut
    /// off at the length limit.
    public func log(
        _ level: LogLevel,
        _ message: @autoclosure () -> String,
        category: String = "default",
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let configuration = configuration
        guard level >= configuration.minimumLevel else { return }
        // Redacted before it is cut, so a cut cannot shorten a secret below what a detector finds.
        let (text, isTruncated) = Self.truncated(configuration.redaction.redact(text: message()), to: configuration.maximumMessageLength)
        let categoryName = Self.truncated(category, to: Self.maximumCategoryLength).text
        let entry = LogEntry(
            date: Date(), level: level, category: categoryName, message: text, isTruncated: isTruncated,
            file: file, function: function, line: line)
        var systemLogger: Logger?
        mutate { state in
            state.entries.append(entry)
            systemLogger = Self.systemLogger(for: categoryName, in: &state)
        }
        systemLogger?.log(level: level.osLogType, "\(text)")
    }

    /// Logs a message at ``LogLevel/debug``.
    public func debug(_ message: @autoclosure () -> String, category: String = "default", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.debug, message(), category: category, file: file, function: function, line: line)
    }

    /// Logs a message at ``LogLevel/info``.
    public func info(_ message: @autoclosure () -> String, category: String = "default", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.info, message(), category: category, file: file, function: function, line: line)
    }

    /// Logs a message at ``LogLevel/notice``.
    public func notice(_ message: @autoclosure () -> String, category: String = "default", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.notice, message(), category: category, file: file, function: function, line: line)
    }

    /// Logs a message at ``LogLevel/warning``.
    public func warning(_ message: @autoclosure () -> String, category: String = "default", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.warning, message(), category: category, file: file, function: function, line: line)
    }

    /// Logs a message at ``LogLevel/error``.
    public func error(_ message: @autoclosure () -> String, category: String = "default", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.error, message(), category: category, file: file, function: function, line: line)
    }

    /// Logs a message at ``LogLevel/fault``.
    public func fault(_ message: @autoclosure () -> String, category: String = "default", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(.fault, message(), category: category, file: file, function: function, line: line)
    }

    /// The messages as text, one per line (see ``LogEntry/formatted``).
    public func exportText(matching filter: LogFilter = LogFilter()) -> String {
        entries(matching: filter).map(\.formatted).joined(separator: "\n")
    }

    // MARK: Internals

    /// The text cut off after at most `limit` Unicode scalars, with `…` appended when it was cut.
    ///
    /// The cut falls between `Character`s, so an emoji or a letter keeps its modifiers and
    /// accents, unless the first `Character` alone is longer than the limit: then it is cut
    /// between scalars.
    static func truncated(_ text: String, to limit: Int) -> (text: String, isTruncated: Bool) {
        let limit = max(limit, 0)
        var end = text.startIndex
        var keptScalars = 0
        while end < text.endIndex {
            let next = text.index(after: end)
            keptScalars += text.unicodeScalars[end..<next].count
            guard keptScalars <= limit else { break }
            end = next
        }
        guard end < text.endIndex else { return (text, false) }
        guard end > text.startIndex else { return (String(text.unicodeScalars.prefix(limit)) + "…", true) }
        return (String(text[..<end]) + "…", true)
    }

    private static func systemLogger(for category: String, in state: inout State) -> Logger? {
        guard let subsystem = state.configuration.systemLogSubsystem else { return nil }
        if let cached = state.systemLoggers[category] { return cached }
        let logger = Logger(subsystem: subsystem, category: category)
        // Categories come from app code; a bounded cache keeps a loop of unique names from growing it.
        if state.systemLoggers.count < systemLoggerCacheLimit {
            state.systemLoggers[category] = logger
        }
        return logger
    }

    private func mutate(_ change: (inout State) -> Void) {
        let observers = state.withLockUnchecked { state -> [AsyncStream<Void>.Continuation] in
            change(&state)
            return Array(state.observers.values)
        }
        observers.forEach { $0.yield() }
    }
}
