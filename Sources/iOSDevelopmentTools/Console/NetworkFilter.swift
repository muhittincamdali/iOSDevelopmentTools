import Foundation

/// Which network entries the console shows.
public struct NetworkFilter: Sendable, Hashable {
    /// Groups of outcomes to show.
    public enum Outcome: String, Sendable, Hashable, CaseIterable, Identifiable {
        case all
        /// Status 200–299.
        case success
        /// Status 300–399.
        case redirect
        /// Status 400–499.
        case clientError
        /// Status 500–599.
        case serverError
        /// No response: a network error or a cancellation.
        case failed
        /// Still loading.
        case pending

        public var id: String { rawValue }

        /// A short name for a picker.
        public var title: String {
            switch self {
            case .all: "All"
            case .success: "2xx"
            case .redirect: "3xx"
            case .clientError: "4xx"
            case .serverError: "5xx"
            case .failed: "Failed"
            case .pending: "Pending"
            }
        }

        func matches(_ entry: NetworkEntry) -> Bool {
            switch self {
            case .all: return true
            case .pending: return entry.state == .pending
            case .failed: return entry.state == .failed
            case .success, .redirect, .clientError, .serverError:
                guard entry.state != .failed, let status = entry.statusCode else { return false }
                return Self.range(for: self).contains(status)
            }
        }

        private static func range(for outcome: Outcome) -> ClosedRange<Int> {
            switch outcome {
            case .success: 200...299
            case .redirect: 300...399
            case .clientError: 400...499
            default: 500...599
            }
        }
    }

    public var outcome: Outcome
    /// Text that the URL, method or status code must contain, ignoring case. Leading and trailing
    /// spaces are ignored; an empty text matches everything.
    public var text: String

    public init(outcome: Outcome = .all, text: String = "") {
        self.outcome = outcome
        self.text = text
    }

    /// Whether the entry passes the filter.
    public func matches(_ entry: NetworkEntry) -> Bool {
        guard outcome.matches(entry) else { return false }
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let haystacks = [entry.url, entry.method, entry.statusCode.map(String.init) ?? ""]
        return haystacks.contains { $0.range(of: needle, options: .caseInsensitive) != nil }
    }
}

/// Text for the console's numbers.
enum ConsoleFormat {
    /// `850 ms`, `1.25 s`, `2 min 5 s`; `–` when there is no finite, non-negative value.
    static func duration(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "–" }
        if seconds < 1 {
            let milliseconds = Int((seconds * 1000).rounded())
            if milliseconds < 1000 { return "\(milliseconds) ms" }
        }
        if seconds < 60 {
            return String(format: "%.2f s", locale: Locale(identifier: "en_US_POSIX"), seconds)
        }
        // Clamp before converting so a huge value cannot trap the Int conversion.
        let total = Int(min(seconds, 1e12).rounded())
        return "\(total / 60) min \(total % 60) s"
    }

    /// `512 bytes`, `1.2 kB`, `3.4 MB` in the user's locale.
    static func bytes(_ count: Int) -> String {
        Int64(max(count, 0)).formatted(.byteCount(style: .file))
    }
}
