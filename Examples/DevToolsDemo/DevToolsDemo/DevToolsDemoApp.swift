import iOSDevelopmentTools
import SwiftUI

@main
struct DevToolsDemoApp: App {
    init() {
        NetworkCapture.start()
        LogStore.shared.info("Demo launched", category: "app")
    }

    var body: some Scene {
        WindowGroup {
            DemoView(options: DemoOptions(arguments: ProcessInfo.processInfo.arguments))
        }
        #if os(macOS)
        Window("Developer Tools", id: "devtools") {
            DevToolsConsole()
        }
        .keyboardShortcut("d", modifiers: [.command, .option])
        #endif
    }
}

/// Launch arguments that let scripts/capture-screens.sh open a given screen:
/// `-run-requests` sends the sample requests at launch, `-console <network|logs|device>` opens the
/// console on that tab once they finished, and `-entry <request name>` opens that request.
struct DemoOptions {
    var runsRequests = false
    var consoleTab: DevToolsConsole.Tab?
    var entryName: String?

    init(arguments: [String]) {
        runsRequests = arguments.contains("-run-requests")
        if let index = arguments.firstIndex(of: "-console"), index + 1 < arguments.count {
            consoleTab = DevToolsConsole.Tab(rawValue: arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "-entry"), index + 1 < arguments.count {
            entryName = arguments[index + 1]
        }
    }
}
