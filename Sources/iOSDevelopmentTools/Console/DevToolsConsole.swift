import SwiftUI

/// The in-app console: recorded requests, log messages and a device report, in three tabs.
///
/// Show it in a sheet with ``SwiftUI/View/devToolsConsole(isPresented:networkLogger:logStore:)``,
/// on a shake with ``SwiftUI/View/devToolsConsoleOnShake(networkLogger:logStore:)`` (iOS), or in
/// a window of its own on macOS:
///
/// ```swift
/// Window("Developer Tools", id: "devtools") {
///     DevToolsConsole()
/// }
/// ```
public struct DevToolsConsole: View {
    /// The console's tabs.
    public enum Tab: String, Hashable, CaseIterable, Sendable {
        case network
        case logs
        case device
    }

    @State private var selection: Tab
    @State private var networkModel: NetworkConsoleModel
    @State private var logModel: LogConsoleModel
    @Environment(\.isPresented) private var isPresented

    /// Creates a console.
    ///
    /// - Parameters:
    ///   - networkLogger: The logger whose requests the Network tab shows.
    ///   - logStore: The store whose messages the Logs tab shows.
    ///   - initialTab: The tab that is selected first.
    public init(networkLogger: NetworkLogger = .shared, logStore: LogStore = .shared, initialTab: Tab = .network) {
        _selection = State(initialValue: initialTab)
        _networkModel = State(initialValue: NetworkConsoleModel(logger: networkLogger))
        _logModel = State(initialValue: LogConsoleModel(store: logStore))
    }

    public var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                NetworkListView(model: networkModel)
            }
            .tabItem { Label("Network", systemImage: "network") }
            .tag(Tab.network)

            NavigationStack {
                LogListView(model: logModel)
            }
            .tabItem { Label("Logs", systemImage: "text.alignleft") }
            .tag(Tab.logs)

            NavigationStack {
                DeviceView()
            }
            .tabItem { Label("Device", systemImage: "info.circle") }
            .tag(Tab.device)
        }
        .tint(ConsoleStyle.accent)
        .environment(\.consoleShowsDoneButton, isPresented)
        .task { await networkModel.follow() }
        .task { await logModel.follow() }
    }
}

/// Colors shared by the console views.
enum ConsoleStyle {
    /// The blue of the project's graphics (#0071E3).
    static let accent = Color(red: 0, green: 0x71 / 255, blue: 0xE3 / 255)
    /// A lighter blue for redirects (#5AC8FA).
    static let redirect = Color(red: 0x5A / 255, green: 0xC8 / 255, blue: 0xFA / 255)

    static func color(for entry: NetworkEntry) -> Color {
        if entry.state == .failed { return .red }
        guard let status = entry.statusCode else { return .secondary }
        switch status {
        case 200..<300: return accent
        case 300..<400: return redirect
        case 400..<500: return .orange
        default: return .red
        }
    }

    static func color(for level: LogLevel) -> Color {
        switch level {
        case .debug: .secondary
        case .info, .notice: accent
        case .warning: .orange
        case .error, .fault: .red
        }
    }
}

extension View {
    /// Presents the console in a sheet while `isPresented` is `true`.
    public func devToolsConsole(
        isPresented: Binding<Bool>,
        networkLogger: NetworkLogger = .shared,
        logStore: LogStore = .shared
    ) -> some View {
        sheet(isPresented: isPresented) {
            DevToolsConsole(networkLogger: networkLogger, logStore: logStore)
                .consoleSheetFrame()
        }
    }

    @ViewBuilder
    func consoleSheetFrame() -> some View {
        #if os(macOS)
        frame(minWidth: 640, idealWidth: 820, minHeight: 480, idealHeight: 640)
        #else
        self
        #endif
    }
}
