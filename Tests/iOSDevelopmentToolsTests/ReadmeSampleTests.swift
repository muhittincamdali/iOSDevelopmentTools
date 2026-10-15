import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Runs the README samples in ReadmeSamples.swift (a link to the example app's copy).
@Suite("README samples", .serialized)
struct ReadmeSampleTests {
    @Test("A session made with install(into:) is recorded")
    func customSession() {
        let session = makeAPISession()
        defer { session.invalidateAndCancel() }
        #expect(session.configuration.protocolClasses?.first { $0 == CaptureProtocol.self } != nil)
        #expect(session.configuration.timeoutIntervalForRequest == 30)
    }

    @Test("The configuration sample sets limits, fragments and ignored hosts")
    func configuration() {
        let previous = NetworkLogger.shared.configuration
        defer { NetworkLogger.shared.configuration = previous }
        configureNetworkLogger()
        let configuration = NetworkLogger.shared.configuration
        #expect(configuration.maximumEntries == 1_000)
        #expect(configuration.maximumBodySize == 512 * 1024)
        #expect(configuration.redaction.isSensitive(name: "IBAN"))
        #expect(configuration.redaction.isSensitive(name: "Authorization"))
        #expect(!configuration.records(host: "eu.analytics.example.com"))
    }

    @Test("The logging sample writes to the shared store")
    func logging() {
        let orderID = UUID().uuidString
        logCheckout(orderID: orderID, error: nil)
        logCheckout(orderID: orderID, error: URLError(.timedOut))
        let entries = LogStore.shared.entries.filter { $0.message.contains(orderID) }
        #expect(entries.map(\.level) == [.info, .error])
        #expect(entries.allSatisfy { $0.category == "checkout" })
    }

    @Test("The export sample produces a HAR file, curl commands and a report")
    func export() throws {
        let request = URLRequest(url: URL(string: "https://api.example.com/readme-sample")!)
        NetworkLogger.shared.record(request: request, response: nil, body: nil, startDate: Date())
        defer { NetworkLogger.shared.clear() }
        let (har, curl, device) = try exportForBugReport()
        #expect(try JSONSerialization.jsonObject(with: har) is [String: Any])
        #expect(curl.contains("curl --globoff 'https://api.example.com/readme-sample'"))
        #expect(device.contains("System: "))
    }
}
