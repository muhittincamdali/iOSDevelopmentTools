import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Log store")
struct LogStoreTests {
    private func store(_ configuration: LogStore.Configuration = .init(systemLogSubsystem: nil)) -> LogStore {
        LogStore(configuration: configuration)
    }

    @Test("Messages keep their level, category and source location")
    func logging() throws {
        let logs = store()
        logs.info("Signed in", category: "auth")
        logs.error("Payment failed", category: "checkout")
        let entries = logs.entries
        #expect(entries.map(\.message) == ["Signed in", "Payment failed"])
        #expect(entries.map(\.level) == [.info, .error])
        #expect(entries.map(\.category) == ["auth", "checkout"])
        let first = try #require(entries.first)
        #expect(first.file == "iOSDevelopmentToolsTests/LogStoreTests.swift")
        #expect(first.function == "logging()")
        #expect(first.line > 0)
        #expect(logs.categories == ["auth", "checkout"])
    }

    @Test("Each convenience method logs at its own level")
    func levels() {
        let logs = store()
        logs.debug("d")
        logs.info("i")
        logs.notice("n")
        logs.warning("w")
        logs.error("e")
        logs.fault("f")
        #expect(logs.entries.map(\.level) == LogLevel.allCases)
        #expect(LogLevel.allCases.map(\.label) == ["DEBUG", "INFO", "NOTICE", "WARNING", "ERROR", "FAULT"])
    }

    @Test("Messages below the minimum level are dropped without building them")
    func minimumLevel() {
        let logs = store(.init(minimumLevel: .warning, systemLogSubsystem: nil))
        var built = 0
        func expensive() -> String {
            built += 1
            return "built"
        }
        logs.debug(expensive())
        logs.warning(expensive())
        #expect(built == 1)
        #expect(logs.entries.map(\.message) == ["built"])
    }

    @Test("Long messages and categories are cut off", arguments: [
        ("abcdef", 3, "abc…", true),
        ("abc", 3, "abc", false),
        // The family is seven scalars and the thumb two: cuts fall between Characters.
        ("👩‍👩‍👧‍👦👍🏽x", 9, "👩‍👩‍👧‍👦👍🏽…", true),
        ("👩‍👩‍👧‍👦👍🏽x", 8, "👩‍👩‍👧‍👦…", true),
        ("👩‍👩‍👧‍👦👍🏽x", 10, "👩‍👩‍👧‍👦👍🏽x", false),
        // Only a first Character longer than the limit is cut between scalars.
        ("👩‍👩‍👧‍👦👍🏽x", 3, "👩\u{200D}👩…", true),
        ("", 1, "", false),
    ])
    func truncation(message: String, limit: Int, expected: String, isTruncated: Bool) throws {
        let logs = store(.init(maximumMessageLength: limit, systemLogSubsystem: nil))
        logs.info(message)
        let entry = try #require(logs.entries.first)
        #expect(entry.message == expected)
        #expect(entry.isTruncated == isTruncated)
    }

    @Test("A huge message costs only the kept characters")
    func hugeMessage() throws {
        let logs = store(.init(maximumMessageLength: 10, systemLogSubsystem: nil))
        logs.info(String(repeating: "x", count: 5_000_000), category: String(repeating: "c", count: 1000))
        let entry = try #require(logs.entries.first)
        #expect(entry.message.count == 11)
        #expect(entry.category.count == LogStore.maximumCategoryLength + 1)
    }

    @Test("Combining marks cannot stretch a message or category past the limit")
    func combiningMarks() throws {
        // One Character of a letter and a million combining marks is 2 MB of UTF-8.
        let logs = store(.init(maximumMessageLength: 16, systemLogSubsystem: nil))
        logs.info("a" + String(repeating: "\u{301}", count: 1_000_000), category: "c" + String(repeating: "\u{301}", count: 500_000))
        let entry = try #require(logs.entries.first)
        #expect(entry.isTruncated)
        #expect(entry.message.unicodeScalars.count == 16 + 1)
        #expect(entry.message.utf8.count <= 16 * 4 + 3)
        #expect(entry.category.unicodeScalars.count == LogStore.maximumCategoryLength + 1)
        #expect(entry.category.utf8.count <= LogStore.maximumCategoryLength * 4 + 3)
    }

    @Test("Limits are clamped", arguments: [(Int.min, Int.min, 1, 1), (Int.max, Int.max, 100_000, 65_536), (10, 20, 10, 20)])
    func clamping(entries: Int, length: Int, expectedEntries: Int, expectedLength: Int) {
        var configuration = LogStore.Configuration(maximumEntries: entries, maximumMessageLength: length)
        #expect(configuration.maximumEntries == expectedEntries)
        #expect(configuration.maximumMessageLength == expectedLength)
        configuration.maximumEntries = entries
        configuration.maximumMessageLength = length
        #expect(configuration.maximumEntries == expectedEntries)
        #expect(configuration.maximumMessageLength == expectedLength)
    }

    @Test("Only the newest messages are kept")
    func capacity() {
        let logs = store(.init(maximumEntries: 3, systemLogSubsystem: nil))
        (1...7).forEach { logs.info("\($0)") }
        #expect(logs.entries.map(\.message) == ["5", "6", "7"])
        logs.configuration.maximumEntries = 2
        #expect(logs.entries.map(\.message) == ["6", "7"])
        logs.configuration.maximumEntries = 5
        logs.info("8")
        #expect(logs.entries.map(\.message) == ["6", "7", "8"])
        logs.clear()
        #expect(logs.entries.isEmpty)
    }

    @Test("Filters combine level, category and text")
    func filtering() {
        let logs = store()
        logs.debug("Cache warmed", category: "cache")
        logs.warning("Retrying request", category: "network")
        logs.error("Request failed: timeout", category: "network")
        logs.error("Café closed", category: "places")

        #expect(logs.entries(matching: LogFilter(minimumLevel: .warning)).count == 3)
        #expect(logs.entries(matching: LogFilter(categories: ["network"])).count == 2)
        #expect(logs.entries(matching: LogFilter(text: "  REQUEST ")).map(\.message) == ["Retrying request", "Request failed: timeout"])
        #expect(logs.entries(matching: LogFilter(text: "cafe")).map(\.category) == ["places"])
        #expect(logs.entries(matching: LogFilter(minimumLevel: .error, categories: ["network"], text: "time")).count == 1)
        #expect(logs.entries(matching: LogFilter(text: "LogStoreTests")).count == 4)
        #expect(logs.entries(matching: LogFilter(minimumLevel: .fault)).isEmpty)
    }

    @Test("Exported text has one line per message")
    func export() throws {
        let entry = LogEntry(
            date: Date(timeIntervalSince1970: 0), level: .warning, category: "net", message: "slow",
            file: "App/Client.swift", function: "load()", line: 42)
        #expect(entry.formatted == "1970-01-01T00:00:00.000Z [WARNING] [net] slow (Client.swift:42)")
        let logs = store()
        logs.info("one")
        logs.info("two")
        #expect(logs.exportText().split(separator: "\n").count == 2)
        #expect(logs.exportText(matching: LogFilter(text: "two")).hasSuffix("two (LogStoreTests.swift:\(#line - 2))"))
    }

    @Test("Messages also go to the unified logging system without failing")
    func systemLog() {
        let logs = LogStore(configuration: .init(systemLogSubsystem: "io.github.muhittincamdali.tests"))
        for index in 0..<(LogStore.systemLoggerCacheLimit + 10) {
            logs.notice("message \(index)", category: "category-\(index)")
        }
        #expect(logs.entries.count == LogStore.systemLoggerCacheLimit + 10)
    }

    @Test("Many threads can log at once")
    func concurrentLogging() async {
        let logs = store(.init(maximumEntries: 1000, systemLogSubsystem: nil))
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<2000 {
                group.addTask { logs.info("\(index)") }
            }
        }
        #expect(logs.entries.count == 1000)
        #expect(Set(logs.entries.map(\.id)).count == 1000)
    }

    @Test("Observers hear about new messages")
    func changes() async {
        let logs = store()
        var iterator = logs.changes().makeAsyncIterator()
        logs.info("hello")
        #expect(await iterator.next() != nil)
    }
}
