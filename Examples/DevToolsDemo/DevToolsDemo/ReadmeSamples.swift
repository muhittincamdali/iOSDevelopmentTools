// The code samples in README.md, compiled by the example app and, through a symbolic link in
// Tests/iOSDevelopmentToolsTests, by `swift test`. Change a sample here and in the README together.

import Foundation
import iOSDevelopmentTools
import SwiftUI

// MARK: Quick start

#if os(iOS)
/// README › Quick start, step 3. (The demo app has its own `@main`; add `@main` in yours.)
struct QuickStartApp: App {
    init() {
        #if DEBUG
        NetworkCapture.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Text("Shake the device to open the console.")
                #if DEBUG
                .devToolsConsoleOnShake()
                #endif
        }
    }
}
#endif

// MARK: Usage

/// README › Open the console from a button.
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}

/// README › Record a session you create yourself.
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}

/// README › Choose what is kept.
func configureNetworkLogger() {
    NetworkLogger.shared.configuration = NetworkLogger.Configuration(
        maximumEntries: 1_000,
        maximumBodySize: 512 * 1024,
        redaction: RedactionPolicy(nameFragments: RedactionPolicy.defaultNameFragments + ["iban", "ssn"]),
        ignoredHosts: ["analytics.example.com"]
    )
}

/// README › Log messages.
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}

/// README › Export requests and reports.
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}

#if os(macOS)
/// README › Use it on macOS.
struct MacDebugScenes: Scene {
    var body: some Scene {
        Window("Developer Tools", id: "devtools") {
            DevToolsConsole()
        }
        .keyboardShortcut("d", modifiers: [.command, .option])
    }
}
#endif
