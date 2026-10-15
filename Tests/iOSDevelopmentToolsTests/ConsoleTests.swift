import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers
import Vision
import os
@testable import iOSDevelopmentTools
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Suite("Console")
@MainActor
struct ConsoleTests {
    private func logger(with outcomes: [(path: String, status: Int?, error: URLError.Code?)]) -> NetworkLogger {
        let logger = NetworkLogger()
        for outcome in outcomes {
            let request = URLRequest(url: URL(string: "https://api.example.com\(outcome.path)")!)
            let response = outcome.status.map { HTTPURLResponse(url: request.url!, statusCode: $0, httpVersion: nil, headerFields: nil)! }
            logger.record(request: request, response: response, body: nil, error: outcome.error.map { URLError($0) }, startDate: Date())
        }
        return logger
    }

    @Test("Outcome filters sort entries by status class and state")
    func outcomes() throws {
        let logger = logger(with: [
            ("/ok", 204, nil), ("/moved", 301, nil), ("/missing", 404, nil), ("/broken", 502, nil),
            ("/offline", nil, .notConnectedToInternet), ("/cancelled", nil, .cancelled),
        ])
        let pendingID = try #require(logger.begin(request: URLRequest(url: URL(string: "https://api.example.com/pending")!), startDate: Date(), bodyPrefix: nil, bodyByteCount: 0))
        let entries = logger.entries
        func paths(_ outcome: NetworkFilter.Outcome) -> [String] {
            entries.filter(NetworkFilter(outcome: outcome).matches).map(\.path)
        }
        #expect(paths(.all).count == 7)
        #expect(paths(.success) == ["/ok"])
        #expect(paths(.redirect) == ["/moved"])
        #expect(paths(.clientError) == ["/missing"])
        #expect(paths(.serverError) == ["/broken"])
        #expect(paths(.failed) == ["/offline", "/cancelled"])
        #expect(paths(.pending) == ["/pending"])
        #expect(logger.entry(id: pendingID)?.state == .pending)
        #expect(NetworkFilter.Outcome.allCases.map(\.title) == ["All", "2xx", "3xx", "4xx", "5xx", "Failed", "Pending"])
    }

    @Test("Search matches URL, method and status code, ignoring case and spaces")
    func search() {
        let entries = logger(with: [("/Users/42", 200, nil), ("/orders", 404, nil)]).entries
        func count(_ text: String) -> Int {
            entries.filter(NetworkFilter(text: text).matches).count
        }
        #expect(count("users") == 1)
        #expect(count(" 404 ") == 1)
        #expect(count("get") == 2)
        #expect(count("API.EXAMPLE") == 2)
        #expect(count("") == 2)
        #expect(count("nothing") == 0)
    }

    @Test("Durations read naturally and never trap", arguments: [
        (nil, "–"), (Double.nan, "–"), (-Double.infinity, "–"), (-0.1, "–"), (0, "0 ms"), (0.0004, "0 ms"),
        (0.8504, "850 ms"), (0.9996, "1.00 s"), (1.257, "1.26 s"), (59.994, "59.99 s"), (125, "2 min 5 s"),
        (Double.infinity, "–"), (1e300, "16666666666 min 40 s"),
    ] as [(Double?, String)])
    func durations(seconds: Double?, expected: String) {
        #expect(ConsoleFormat.duration(seconds) == expected)
    }

    @Test("Negative byte counts are shown as zero")
    func bytes() {
        #expect(ConsoleFormat.bytes(-5) == ConsoleFormat.bytes(0))
    }

    @Test("The network model follows the logger, newest first")
    func networkModelFollows() async throws {
        let logger = logger(with: [("/first", 200, nil)])
        let model = NetworkConsoleModel(logger: logger)
        #expect(model.visibleEntries.map(\.path) == ["/first"])
        let following = Task { await model.follow() }
        defer { following.cancel() }
        logger.record(request: URLRequest(url: URL(string: "https://api.example.com/second")!), response: nil, body: nil, startDate: Date())
        for _ in 0..<100 where model.entries.count < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.visibleEntries.map(\.path) == ["/second", "/first"])
        model.filter.text = "first"
        #expect(model.visibleEntries.map(\.path) == ["/first"])
        model.clear()
        #expect(model.entries.isEmpty && logger.entries.isEmpty)
    }

    @Test("The log model filters, lists categories and exports oldest first")
    func logModel() {
        let store = LogStore(configuration: .init(systemLogSubsystem: nil))
        store.info("one", category: "b")
        store.error("two", category: "a")
        let model = LogConsoleModel(store: store)
        #expect(model.visibleEntries.map(\.message) == ["two", "one"])
        #expect(model.categories == ["a", "b"])
        model.filter.minimumLevel = .error
        #expect(model.visibleEntries.map(\.message) == ["two"])
        model.filter = LogFilter()
        #expect(model.exportText.split(separator: "\n").map { $0.contains("one") } == [true, false])
        model.clear()
        #expect(store.entries.isEmpty)
    }

    @Test("The HAR file for sharing holds the entries")
    @available(macOS 15.2, iOS 18.2, *)
    func harFile() async throws {
        let entries = logger(with: [("/a", 200, nil), ("/b", 500, nil)]).entries
        let data = try await HTTPArchiveFile(entries: entries).exported(as: .json)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let log = try #require(root["log"] as? [String: Any])
        #expect((log["entries"] as? [Any])?.count == 2)
    }

    /// The text in the view as drawn: the view is shown in a phone-sized window, rendered and
    /// read back with Vision's text recognition. Rendering is repeated for a moment, because lists
    /// fill their rows in later layout passes.
    private func renderedText(of view: some View, expecting expected: [String]) throws -> String {
        let size = CGSize(width: 390, height: 844)
        #if canImport(UIKit)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        defer { window.isHidden = true }
        func snapshot() throws -> CGImage {
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: size).image { context in
                window.layer.render(in: context.cgContext)
            }
            return try #require(image.cgImage)
        }
        #else
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        func snapshot() throws -> CGImage {
            host.layoutSubtreeIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            return try #require(bitmap.cgImage)
        }
        #endif
        var text = ""
        for _ in 0..<20 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            text = try recognizedText(in: snapshot())
            if expected.allSatisfy(text.contains) { break }
        }
        return text
    }

    private func recognizedText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    @Test("The Network and Logs tabs draw the recorded content, and say so when empty", arguments: [DevToolsConsole.Tab.network, .logs])
    func consoleDrawsContent(tab: DevToolsConsole.Tab) throws {
        let logger = logger(with: [("/alpha", 200, nil), ("/beta", nil, .timedOut)])
        let store = LogStore(configuration: .init(systemLogSubsystem: nil))
        store.warning("careful message", category: "checkout")
        let expected = tab == .network ? ["/alpha", "/beta", "200"] : ["careful message", "checkout"]
        let text = try renderedText(of: DevToolsConsole(networkLogger: logger, logStore: store, initialTab: tab), expecting: expected)
        for string in expected {
            #expect(text.contains(string), "\(string) is not drawn in the \(tab) tab: \(text)")
        }

        let empty = DevToolsConsole(networkLogger: NetworkLogger(), logStore: LogStore(configuration: .init(systemLogSubsystem: nil)), initialTab: tab)
        let emptyTitle = tab == .network ? "No Requests" : "No Messages"
        let emptyText = try renderedText(of: empty, expecting: [emptyTitle])
        #expect(emptyText.contains(emptyTitle), "The empty \(tab) tab draws: \(emptyText)")
        #expect(!emptyText.contains("/alpha") && !emptyText.contains("careful message"))
    }

    @Test("The Device tab draws the device report")
    func deviceDrawsContent() throws {
        // Rendered outside the TabView: an offscreen render on the iOS simulator draws no rows of
        // a long Form inside a selected tab, although the app shows them.
        let expected = ["Model", "Thermal state", "Debugger"]
        let text = try renderedText(of: NavigationStack { DeviceView() }, expecting: expected)
        for string in expected {
            #expect(text.contains(string), "\(string) is not drawn in the Device tab: \(text)")
        }
    }

    @Test("A request's detail view draws its method, status and why a body was withheld")
    func detailDrawsContent() throws {
        let logger = NetworkLogger(configuration: .init(maximumBodySize: 8))
        var request = URLRequest(url: URL(string: "https://api.example.com/upload?token=x")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"password":"a-long-secret"}"#.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: ["Content-Type": "image/png"])
        let id = try #require(logger.record(request: request, response: response, body: Data([0, 1, 2]), startDate: Date()))
        let entry = try #require(logger.entry(id: id))
        #expect(entry.requestBody?.redaction == .withheld)
        let expected = ["POST", "201", "Withheld"]
        let text = try renderedText(of: NavigationStack { NetworkEntryView(entry: entry) }, expecting: expected)
        for string in expected {
            #expect(text.contains(string), "\(string) is not drawn in the detail view: \(text)")
        }
        #expect(!text.contains("a-long-secret"))
    }

    @Test("Every log level has its own symbol, and the symbol exists")
    func levelSymbols() {
        let symbols = LogLevel.allCases.map(LogRow.symbol(for:))
        #expect(Set(symbols).count == LogLevel.allCases.count)
        for symbol in symbols {
            #if canImport(UIKit)
            #expect(UIImage(systemName: symbol) != nil, "\(symbol) is not an SF Symbol")
            #else
            #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol) is not an SF Symbol")
            #endif
        }
    }

    #if os(iOS)
    @Test("Shaking a window posts the notification; other responders are unchanged")
    func shake() async {
        ShakeDetection.install()
        ShakeDetection.install()
        let received = OSAllocatedUnfairLock(initialState: 0)
        let observer = NotificationCenter.default.addObserver(forName: .devToolsDeviceDidShake, object: nil, queue: nil) { _ in
            received.withLock { $0 += 1 }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let window = UIWindow(frame: .zero)
        window.motionEnded(.motionShake, with: nil)
        window.motionEnded(.remoteControlPlay, with: nil)
        UIView().motionEnded(.motionShake, with: nil)
        #expect(received.withLock { $0 } == 1)
        #expect(ShakeDetection.isInstalled)
    }
    #endif
}
