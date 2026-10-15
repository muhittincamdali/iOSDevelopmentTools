import Foundation
import ObjectiveC
import os

/// Records the HTTP and HTTPS requests an app makes with `URLSession`.
///
/// Call ``start(logger:)`` once, early, for example in your app's `init`. From then on the
/// requests of `URLSession.shared` and of every session created from
/// `URLSessionConfiguration.default` or `.ephemeral` are recorded in the logger. A session that
/// was created before ``start(logger:)``, or from a configuration you made some other way, can be
/// included with ``install(into:)``.
///
/// Recorded requests are sent on by an internal session with the default configuration. Settings
/// of your own session that live outside the request (its delegate's authentication and
/// certificate handling, `waitsForConnectivity`, a custom `URLCache`) do not apply to them, and
/// background sessions are not recorded. Use it in debug and test builds.
public enum NetworkCapture {
    private struct State: Sendable {
        var logger: NetworkLogger?
        var isRegistered = false
        var isSwizzled = false
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    /// Starts recording requests into `logger`. Calling it again switches to another logger.
    public static func start(logger: NetworkLogger = .shared) {
        state.withLock { state in
            state.logger = logger
            if !state.isRegistered {
                URLProtocol.registerClass(CaptureProtocol.self)
                state.isRegistered = true
            }
            if !state.isSwizzled {
                URLSessionConfiguration.exchangeCapturingFactories()
                state.isSwizzled = true
            }
        }
    }

    /// Stops recording. Requests that are already being recorded finish normally.
    public static func stop() {
        state.withLock { state in
            state.logger = nil
            if state.isRegistered {
                URLProtocol.unregisterClass(CaptureProtocol.self)
                state.isRegistered = false
            }
            if state.isSwizzled {
                URLSessionConfiguration.exchangeCapturingFactories()
                state.isSwizzled = false
            }
        }
    }

    /// Whether requests are being recorded.
    public static var isCapturing: Bool {
        state.withLock { $0.logger != nil }
    }

    /// The logger requests are recorded into, while capturing.
    public static var logger: NetworkLogger? {
        state.withLock { $0.logger }
    }

    /// Adds request recording to a session configuration.
    ///
    /// Create the session after calling this; a session copies its configuration when it is
    /// created. Requests are recorded only while capture is started.
    public static func install(into configuration: URLSessionConfiguration) {
        var classes = configuration.protocolClasses ?? []
        guard !classes.contains(where: { $0 == CaptureProtocol.self }) else { return }
        classes.insert(CaptureProtocol.self, at: 0)
        configuration.protocolClasses = classes
    }

    // MARK: Forwarding

    /// Replaces the session that sends recorded requests on. Tests use it to answer requests
    /// without a network.
    static func setForwardingProtocolClasses(_ classes: [AnyClass]) {
        ForwardingSession.replace(protocolClasses: classes)
    }
}

extension URLSessionConfiguration {
    /// Swaps `default` and `ephemeral` with versions that call ``NetworkCapture/install(into:)``.
    /// Calling it a second time swaps them back.
    fileprivate static func exchangeCapturingFactories() {
        let pairs: [(Selector, Selector)] = [
            (#selector(getter: URLSessionConfiguration.default), #selector(URLSessionConfiguration.idt_capturingDefault)),
            (#selector(getter: URLSessionConfiguration.ephemeral), #selector(URLSessionConfiguration.idt_capturingEphemeral)),
        ]
        for (original, replacement) in pairs {
            guard let originalMethod = class_getClassMethod(URLSessionConfiguration.self, original),
                  let replacementMethod = class_getClassMethod(URLSessionConfiguration.self, replacement)
            else { continue }
            method_exchangeImplementations(originalMethod, replacementMethod)
        }
    }

    // After the exchange these names call the original implementations.
    @objc fileprivate class func idt_capturingDefault() -> URLSessionConfiguration {
        let configuration = idt_capturingDefault()
        NetworkCapture.install(into: configuration)
        return configuration
    }

    @objc fileprivate class func idt_capturingEphemeral() -> URLSessionConfiguration {
        let configuration = idt_capturingEphemeral()
        NetworkCapture.install(into: configuration)
        return configuration
    }
}
