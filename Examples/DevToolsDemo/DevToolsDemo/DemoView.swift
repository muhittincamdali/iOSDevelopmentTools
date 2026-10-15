import iOSDevelopmentTools
import SwiftUI

/// A request the demo can send, to public services that answer without an account.
struct SampleRequest: Identifiable {
    let name: String
    let summary: String
    let request: URLRequest

    var id: String { name }

    static let all: [SampleRequest] = [
        SampleRequest(name: "Repository", summary: "JSON from the GitHub API", request: get("https://api.github.com/repos/swiftlang/swift", accept: "application/vnd.github+json")),
        SampleRequest(name: "Zen", summary: "Plain text", request: get("https://api.github.com/zen")),
        SampleRequest(name: "Sign in", summary: "A password and a bearer token, redacted", request: signIn()),
        SampleRequest(name: "Search", summary: "An API key in the query, redacted", request: get("https://postman-echo.com/get?q=swift&api_key=demo-key-456")),
        SampleRequest(name: "Missing page", summary: "404 Not Found", request: get("https://api.github.com/repos/swiftlang/swift/no-such-page")),
        SampleRequest(name: "Server error", summary: "503 Service Unavailable", request: get("https://postman-echo.com/status/503")),
        SampleRequest(name: "Offline host", summary: "A host that does not exist", request: get("https://offline.invalid/")),
    ]

    private static func get(_ url: String, accept: String? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        return request
    }

    private static func signIn() -> URLRequest {
        var request = URLRequest(url: URL(string: "https://postman-echo.com/post")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer demo-token-123", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(#"{"email":"ada@example.com","password":"correct horse battery staple","remember":true}"#.utf8)
        return request
    }
}

struct DemoView: View {
    let options: DemoOptions
    @State private var results: [String: String] = [:]
    @State private var isRunning = false
    @State private var showsConsole = false
    @State private var shownEntry: NetworkEntry?
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SampleRequest.all) { sample in
                        Button {
                            Task { await send(sample) }
                        } label: {
                            LabeledContent {
                                Text(results[sample.name] ?? "")
                                    .monospacedDigit()
                            } label: {
                                Text(sample.name)
                                Text(sample.summary)
                            }
                        }
                    }
                } header: {
                    Text("Requests")
                } footer: {
                    Text("Each request goes through URLSession.shared and is recorded by NetworkCapture.")
                }
                Section {
                    Button("Send All") {
                        Task { await sendAll() }
                    }
                    .disabled(isRunning)
                    Button("Open Developer Tools") { openConsole() }
                } footer: {
                    #if os(iOS)
                    Text("You can also shake the device (in the simulator: Device › Shake).")
                    #else
                    Text("Or press ⌥⌘D.")
                    #endif
                }
            }
            .navigationTitle("DevTools Demo")
        }
        #if os(iOS)
        .devToolsConsoleOnShake()
        #endif
        .sheet(isPresented: $showsConsole) {
            DevToolsConsole(initialTab: options.consoleTab ?? .network)
                #if os(macOS)
                .frame(minWidth: 640, minHeight: 480)
                #endif
        }
        .sheet(item: $shownEntry) { entry in
            NavigationStack {
                NetworkEntryView(entry: entry)
            }
            #if os(macOS)
            .frame(minWidth: 520, minHeight: 600)
            #endif
        }
        .task {
            guard options.runsRequests else { return }
            await sendAll()
            if let name = options.entryName {
                shownEntry = entry(named: name)
            } else if options.consoleTab != nil {
                showsConsole = true
            }
        }
    }

    private func openConsole() {
        #if os(macOS)
        openWindow(id: "devtools")
        #else
        showsConsole = true
        #endif
    }

    private func sendAll() async {
        isRunning = true
        for sample in SampleRequest.all {
            await send(sample)
        }
        isRunning = false
    }

    private func send(_ sample: SampleRequest) async {
        results[sample.name] = "…"
        do {
            let (data, response) = try await URLSession.shared.data(for: sample.request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            results[sample.name] = "\(status)"
            let level: LogLevel = status >= 400 ? .warning : .info
            LogStore.shared.log(level, "\(sample.name): \(status), \(data.count) bytes", category: "network")
        } catch {
            results[sample.name] = "Failed"
            LogStore.shared.error("\(sample.name) failed: \(error.localizedDescription)", category: "network")
        }
    }

    /// The most recent recorded request for a sample, matched on its redacted URL.
    private func entry(named name: String) -> NetworkEntry? {
        guard let sample = SampleRequest.all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
              let url = sample.request.url
        else { return nil }
        let redacted = NetworkLogger.shared.configuration.redaction.redact(url: url)
        return NetworkLogger.shared.entries.last { $0.url == redacted }
    }
}
