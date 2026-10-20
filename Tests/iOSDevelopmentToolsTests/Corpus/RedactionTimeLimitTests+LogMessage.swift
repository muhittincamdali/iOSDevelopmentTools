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
}
