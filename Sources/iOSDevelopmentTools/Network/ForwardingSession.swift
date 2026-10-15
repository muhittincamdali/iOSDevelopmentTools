import Foundation
import os

/// Receives the delegate callbacks of a forwarded request.
protocol ForwardedTaskHandler: AnyObject, Sendable {
    func forwardedTask(didReceive response: URLResponse) -> URLSession.ResponseDisposition
    func forwardedTask(didReceive data: Data)
    func forwardedTask(willRedirectWith response: HTTPURLResponse, to request: URLRequest) -> URLRequest?
    func forwardedTask(didFinishCollecting metrics: URLSessionTaskMetrics)
    func forwardedTask(didCompleteWithError error: (any Error)?)
}

/// The session that sends recorded requests on, and routes each task's callbacks to its handler.
final class ForwardingSession: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private static let current = OSAllocatedUnfairLock<ForwardingSession?>(initialState: nil)

    /// The session in use, created on first use.
    static var shared: ForwardingSession {
        current.withLock { current in
            if let current { return current }
            let created = ForwardingSession(protocolClasses: nil)
            current = created
            return created
        }
    }

    /// Replaces the session. The old one finishes its tasks and is then released.
    static func replace(protocolClasses: [AnyClass]?) {
        let old = current.withLock { current in
            let old = current
            current = ForwardingSession(protocolClasses: protocolClasses)
            return old
        }
        old?.session.finishTasksAndInvalidate()
    }

    private let handlers = OSAllocatedUnfairLock<[Int: any ForwardedTaskHandler]>(initialState: [:])
    private var session: URLSession!

    private init(protocolClasses: [AnyClass]?) {
        super.init()
        let configuration = URLSessionConfiguration.default
        // Never record our own forwarded requests.
        var classes = (configuration.protocolClasses ?? []).filter { $0 != CaptureProtocol.self }
        if let protocolClasses { classes.insert(contentsOf: protocolClasses, at: 0) }
        configuration.protocolClasses = classes
        let queue = OperationQueue()
        queue.name = "iOSDevelopmentTools.ForwardingSession"
        queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    }

    /// Starts a task for the request and sends its callbacks to `handler`.
    func start(_ request: URLRequest, handler: any ForwardedTaskHandler) -> URLSessionDataTask {
        let task = session.dataTask(with: request)
        handlers.withLock { $0[task.taskIdentifier] = handler }
        task.resume()
        return task
    }

    private func handler(for task: URLSessionTask) -> (any ForwardedTaskHandler)? {
        handlers.withLock { $0[task.taskIdentifier] }
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        completionHandler(handler(for: dataTask)?.forwardedTask(didReceive: response) ?? .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        handler(for: dataTask)?.forwardedTask(didReceive: data)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(handler(for: task)?.forwardedTask(willRedirectWith: response, to: request))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        handler(for: task)?.forwardedTask(didFinishCollecting: metrics)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let handler = handlers.withLock { $0.removeValue(forKey: task.taskIdentifier) }
        handler?.forwardedTask(didCompleteWithError: error)
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask,
        willCacheResponse proposedResponse: CachedURLResponse,
        completionHandler: @escaping @Sendable (CachedURLResponse?) -> Void
    ) {
        completionHandler(proposedResponse)
    }
}
