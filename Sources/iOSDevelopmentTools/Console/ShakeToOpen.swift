#if os(iOS)
import ObjectiveC
import SwiftUI
import UIKit

extension Notification.Name {
    /// Posted on the main thread when the device is shaken, once
    /// ``SwiftUICore/View/devToolsConsoleOnShake(networkLogger:logStore:)`` is in use.
    public static let devToolsDeviceDidShake = Notification.Name("io.github.muhittincamdali.iOSDevelopmentTools.deviceDidShake")
}

extension View {
    /// Presents the console in a sheet when the device is shaken (in the simulator:
    /// **Device › Shake**).
    ///
    /// The first use adds a `motionEnded(_:with:)` implementation to `UIWindow` that calls the
    /// existing one and then posts ``Foundation/NSNotification/Name/devToolsDeviceDidShake``. Other
    /// responders are not changed, and nothing is changed until the modifier is used.
    public func devToolsConsoleOnShake(networkLogger: NetworkLogger = .shared, logStore: LogStore = .shared) -> some View {
        modifier(ShakeToOpenModifier(networkLogger: networkLogger, logStore: logStore))
    }
}

private struct ShakeToOpenModifier: ViewModifier {
    let networkLogger: NetworkLogger
    let logStore: LogStore
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onAppear { ShakeDetection.install() }
            .onReceive(NotificationCenter.default.publisher(for: .devToolsDeviceDidShake)) { _ in
                isPresented = true
            }
            .devToolsConsole(isPresented: $isPresented, networkLogger: networkLogger, logStore: logStore)
    }
}

@MainActor
enum ShakeDetection {
    private(set) static var isInstalled = false

    /// Adds shake reporting to `UIWindow`. Safe to call more than once.
    ///
    /// The new implementation calls the previous one with the original selector. Exchanging the
    /// method with a renamed one would not work: `UIResponder` passes motion events up the
    /// responder chain using the selector it was called with, and the window scene does not know
    /// a renamed selector.
    static func install() {
        guard !isInstalled else { return }
        isInstalled = true
        let selector = #selector(UIResponder.motionEnded(_:with:))
        // UIWindow's own implementation, or the one it inherits from UIResponder.
        guard let method = class_getInstanceMethod(UIWindow.self, selector) else { return }
        typealias MotionEnded = @convention(c) (AnyObject, Selector, UIEvent.EventSubtype, UIEvent?) -> Void
        let previous = unsafeBitCast(method_getImplementation(method), to: MotionEnded.self)
        let replacement: @convention(block) (AnyObject, UIEvent.EventSubtype, UIEvent?) -> Void = { window, motion, event in
            previous(window, selector, motion, event)
            if motion == .motionShake {
                NotificationCenter.default.post(name: .devToolsDeviceDidShake, object: window)
            }
        }
        let implementation = imp_implementationWithBlock(replacement)
        // Adding the method to UIWindow leaves UIResponder, and every other responder, unchanged.
        if !class_addMethod(UIWindow.self, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
    }
}
#endif
