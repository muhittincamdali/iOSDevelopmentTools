import Foundation
import Testing
@testable import iOSDevelopmentTools

extension RedactionTimeLimitTests {
    // LogStore.log redacts a message on the thread that logs before it cuts it off; the third
    // review of 2.1.0 found that a large message held that thread for seconds, minutes for a
    // large enough one. Past LogStore.maximumRedactedMessageLength the rest is hidden unread.
    @Test("logging a message of eight megabytes of quotes takes a 512 KiB thread less than a second")
    func largeLogMessage() {
        let line = Self.oneLongString("say \\\"hi\\\" ", then: "ayse@ornek.com", total: 4_096) + "\n"
        let message = String(repeating: line, count: 8 * 1_048_576 / line.utf8.count)
        let store = LogStore(configuration: .init(systemLogSubsystem: nil))
        let (time, kept) = onThread(stackSize: RedactionStackTests.threadStack) {
            let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
            store.info(message)
            let time = Duration.nanoseconds(Int64(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start))
            return (time, store.entries.first?.message ?? "")
        }
        #expect(time < Self.limit, "\(time)")
        #expect(!kept.contains("ayse@ornek.com"))
    }

    // The seventeenth review: a message of a million different characters outside ASCII, about
    // four megabytes, is shorter in scalars than the limit and is redacted whole; it took 1.46 s
    // and 70.5 MiB with a reading kept for each character.
    @Test("logging a message of a million different characters takes less than a second a megabyte")
    func logMessageOfDifferentCharacters() {
        let message = DistinctScalarShapes.logMessage()
        let megabytes = Double(message.utf8.count) / 1_000_000
        var fastest = Duration.seconds(1_000)
        for _ in 0..<3 where fastest >= Self.limit * megabytes {
            fastest = min(fastest, onThread(stackSize: RedactionStackTests.threadStack) {
                let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
                _ = LogStore.redacted(message, with: .default)
                return Duration.nanoseconds(Int64(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start))
            })
        }
        #expect(fastest < Self.limit * megabytes, "\(fastest) for \(megabytes) MB")
    }
}
