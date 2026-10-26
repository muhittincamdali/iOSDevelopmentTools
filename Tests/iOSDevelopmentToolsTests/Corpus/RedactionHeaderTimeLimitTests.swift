import Foundation
import Testing
@testable import iOSDevelopmentTools

/// What a 512 KiB thread did with a response of many header fields.
private struct HeaderRun: Sendable {
    let seconds: Double
    let fieldCount: Int
    let redactedCount: Int
    let accept: String?
}

/// A review of iOS-Networking-Architecture-Pro found headers read and redacted there in time that
/// grew with the square of their number: 20,000 response header fields (658 KB) took 6.6 s to
/// redact. A hostile server can send that many; URLSession accepts them. Here the network logger
/// reads them from the `HTTPURLResponse`, sorts and redacts them with one table of readings.
@Suite("Redaction corpus: header time limit", .serialized, .enabled(if: isOptimized, "time limits are checked in a release build: swift test -c release"))
struct RedactionHeaderTimeLimitTests {
    /// Recording a response with the network logger: reading its header fields and redacting them.
    private static func run(_ response: HTTPURLResponse) -> HeaderRun {
        onThread(stackSize: RedactionStackTests.threadStack) {
            let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
            let logger = NetworkLogger()
            let request = URLRequest(url: URL(string: "https://api.example.com/a")!)
            let id = logger.record(request: request, response: response, body: Data(), startDate: Date())
            let headers = id.flatMap(logger.entry(id:))?.responseHeaders ?? []
            let nanoseconds = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start
            return HeaderRun(seconds: Double(nanoseconds) / 1e9, fieldCount: response.allHeaderFields.count, redactedCount: headers.count,
                             accept: headers.first { $0.name.lowercased() == "accept" }?.value)
        }
    }

    @Test("recording and redacting many response header fields takes a 512 KiB thread less than a second per megabyte",
          arguments: [10_000, 20_000, 32_000])
    func manyFields(count: Int) {
        var fields: [String: String] = ["Accept": "application/json"]
        for i in 0..<count { fields["X-H\(i)"] = "value \(i) status=200" }
        let response = HTTPURLResponse(url: URL(string: "https://api.example.com/a")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: fields)!
        let megabytes = Double(fields.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count + 4 }) / 1e6
        var run = Self.run(response)
        for _ in 0..<2 where run.seconds >= megabytes {
            run = Self.run(response)
        }
        #expect(run.fieldCount == count + 1 && run.redactedCount == count + 1)
        #expect(run.accept == "application/json")
        #expect(run.seconds < megabytes, "\(count) fields, \(megabytes) MB: \(run.seconds) s")
    }
}
