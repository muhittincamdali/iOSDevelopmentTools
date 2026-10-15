import Foundation
import os

/// The `URLProtocol` that records a request, sends it on through ``ForwardingSession`` and
/// passes the response back to the session that made the request.
///
/// `URLProtocolClient` must be called on the thread that called ``startLoading()``, so every
/// client call is scheduled on that thread's run loop, as in Apple's CustomHTTPProtocol sample.
final class CaptureProtocol: URLProtocol, ForwardedTaskHandler, @unchecked Sendable {
    /// Marks requests this protocol already handles, so the forwarded copy is not captured again.
    static let handledKey = "io.github.muhittincamdali.iOSDevelopmentTools.captured"

    /// Bodies up to this size are read into memory and sent as `Data`, which keeps their
    /// `Content-Length`; larger ones are streamed.
    static let inMemoryBodyLimit = 4 * 1024 * 1024

    /// How long after reporting a redirect the app's session is given to follow it, by stopping
    /// this load, before the redirect counts as refused and its response is passed on.
    static let redirectDecisionTime: DispatchTimeInterval = .milliseconds(500)

    /// Where a redirect stands. The app's session follows a redirect by stopping this load and
    /// starting a new one; it gives no signal when its delegate refuses one.
    private enum Redirect {
        case none
        /// Reported to the app's session, which has not stopped this load yet.
        case pending
        /// Not followed in time: the redirect response goes to the app as the final response.
        case refused
    }

    /// A forwarded response held back while a redirect is pending, with the forwarding
    /// session's disposition handler, which is called once the redirect is followed or refused.
    private struct HeldResponse {
        let response: URLResponse
        let completionHandler: @Sendable (URLSession.ResponseDisposition) -> Void
    }

    /// The end of the forwarded task, held back while a redirect is pending.
    private struct HeldCompletion {
        let error: (any Error)?
    }

    private struct State {
        var task: URLSessionDataTask?
        var pump: RequestBodyPump?
        var entryID: NetworkEntry.ID?
        var logger: NetworkLogger?
        var bodyLimit = 0
        var responseBody = Data()
        var responseByteCount = 0
        var timings: NetworkEntry.Timings?
        var networkProtocol: String?
        var isStopped = false
        var redirect = Redirect.none
        var heldResponse: HeldResponse?
        var heldCompletion: HeldCompletion?
        var isCompleted = false
    }

    private let state = OSAllocatedUnfairLock(uncheckedState: State())
    private var clientThread: Thread?
    private var runLoopModes: [String] = [RunLoop.Mode.default.rawValue]

    override class func canInit(with request: URLRequest) -> Bool {
        guard let logger = NetworkCapture.logger,
              let scheme = request.url?.scheme?.lowercased(), scheme == "http" || scheme == "https",
              URLProtocol.property(forKey: handledKey, in: request) == nil
        else { return false }
        return logger.configuration.records(host: request.url?.host())
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        clientThread = Thread.current
        if let mode = RunLoop.current.currentMode, mode != .default {
            runLoopModes = [mode.rawValue, RunLoop.Mode.default.rawValue]
        }
        guard let forwarded = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: forwarded)

        let logger = NetworkCapture.logger
        let bodyLimit = logger?.configuration.maximumBodySize ?? 0
        var bodyPrefix: Data?
        var bodyByteCount = 0
        var pump: RequestBodyPump?

        if let stream = request.httpBodyStream {
            switch RequestBodyReader.read(stream, bufferLimit: max(Self.inMemoryBodyLimit, bodyLimit)) {
            case .complete(let body):
                forwarded.httpBodyStream = nil
                forwarded.httpBody = body
                bodyPrefix = body.prefix(bodyLimit)
                bodyByteCount = body.count
            case .partial(let prefix, let remainder):
                pump = RequestBodyPump(prefix: prefix, remainder: remainder) { [weak self] error in
                    self?.failForwarding(with: error)
                }
                guard let pump else {
                    client?.urlProtocol(self, didFailWithError: URLError(.cannotCreateFile))
                    return
                }
                forwarded.httpBodyStream = pump.inputStream
                bodyPrefix = prefix.prefix(bodyLimit)
                bodyByteCount = prefix.count
            case .failed(let error):
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
        } else if let body = request.httpBody {
            bodyPrefix = body.prefix(bodyLimit)
            bodyByteCount = body.count
        }

        let entryID = logger?.begin(
            request: request, startDate: Date(), bodyPrefix: bodyPrefix, bodyByteCount: bodyByteCount)
        state.withLockUnchecked { state in
            state.logger = entryID == nil ? nil : logger
            state.entryID = entryID
            state.bodyLimit = bodyLimit
            state.pump = pump
        }
        pump?.start()
        let task = ForwardingSession.shared.start(forwarded as URLRequest, handler: self)
        let stoppedMeanwhile = state.withLockUnchecked { state -> Bool in
            state.task = task
            return state.isStopped
        }
        if stoppedMeanwhile { task.cancel() }
    }

    override func stopLoading() {
        let (task, pump, logger, entryID, held, ended) = state.withLockUnchecked { state in
            let ended = state.isStopped || state.redirect != .none || state.isCompleted
            state.isStopped = true
            let held = state.heldResponse
            state.heldResponse = nil
            state.heldCompletion = nil
            return (state.task, state.pump, state.logger, state.entryID, held, ended)
        }
        pump?.cancel()
        task?.cancel()
        held?.completionHandler(.cancel)
        guard !ended else { return }
        // The app cancelled the request; the forwarded task's own completion is ignored now.
        if let logger, let entryID {
            logger.finish(entryID, bodyPrefix: Data(), bodyByteCount: 0, error: URLError(.cancelled))
        }
    }

    // MARK: Forwarded task callbacks (on the forwarding session's queue)

    func forwardedTask(
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        let (isHeld, isStopped, logger, entryID) = state.withLockUnchecked { state in
            let isHeld = state.redirect == .pending && !state.isStopped
            if isHeld { state.heldResponse = HeldResponse(response: response, completionHandler: completionHandler) }
            // After a refused redirect the entry already holds the redirect response.
            let records = state.redirect == .none
            return (isHeld, state.isStopped, records ? state.logger : nil, state.entryID)
        }
        guard !isHeld else { return }
        guard !isStopped else { return completionHandler(.cancel) }
        if let logger, let entryID { logger.receive(response: response, for: entryID) }
        deliver { protocolInstance, client in
            client.urlProtocol(protocolInstance, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        completionHandler(.allow)
    }

    func forwardedTask(didReceive data: Data) {
        let ended = state.withLockUnchecked { state -> Bool in
            guard !state.isStopped else { return true }
            // The body of a refused redirect goes to the app but not into the ended entry.
            guard state.redirect == .none else { return false }
            let room = state.bodyLimit - state.responseBody.count
            if room > 0 { state.responseBody.append(data.prefix(room)) }
            state.responseByteCount = state.responseByteCount.addingReportingOverflow(data.count).overflow
                ? Int.max : state.responseByteCount + data.count
            return false
        }
        guard !ended else { return }
        deliver { protocolInstance, client in
            client.urlProtocol(protocolInstance, didLoad: data)
        }
    }

    /// Reports the redirect to the app's session and lets the forwarded task go on to the
    /// redirect response, which is held back until the app's session decides.
    ///
    /// Nothing that ends this load is sent with the redirect. Apple's CustomHTTPProtocol sample
    /// fails the load right after reporting the redirect, but the session can take that failure
    /// before it has switched to the redirected request: about one load in two thousand then
    /// ended in `CocoaError(.userCancelled)` instead of the redirect target, and a response
    /// sent at that moment could finish the app's task twice. A session that follows the
    /// redirect stops this load and starts a new one for the redirected request; a session whose
    /// delegate refuses it does nothing, so after ``redirectDecisionTime`` the held redirect
    /// response and its body go to the app, as a refused redirect returns them without capture.
    func forwardedTask(willRedirectWith response: HTTPURLResponse, to request: URLRequest) -> URLRequest? {
        guard let redirect = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return request }
        // The redirected request goes back through the app's session, which captures it again.
        URLProtocol.removeProperty(forKey: Self.handledKey, in: redirect)
        let redirectRequest = redirect as URLRequest
        let (logger, entryID, isStopped) = state.withLockUnchecked { state in
            if !state.isStopped { state.redirect = .pending }
            return (state.logger, state.entryID, state.isStopped)
        }
        guard !isStopped else { return nil }
        if let logger, let entryID { logger.redirect(entryID, response: response, to: redirectRequest) }
        deliver { protocolInstance, client in
            client.urlProtocol(protocolInstance, wasRedirectedTo: redirectRequest, redirectResponse: response)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.redirectDecisionTime) { [weak self] in
            self?.deliver { protocolInstance, client in
                protocolInstance.passOnRefusedRedirect(to: client)
            }
        }
        return nil
    }

    /// Runs on the client thread once ``redirectDecisionTime`` has passed: when the app's
    /// session has not stopped this load, it refused the redirect, and the held response goes on.
    private func passOnRefusedRedirect(to client: any URLProtocolClient) {
        let (held, completion) = state.withLockUnchecked { state -> (HeldResponse?, HeldCompletion?) in
            guard state.redirect == .pending, !state.isStopped else { return (nil, nil) }
            state.redirect = .refused
            defer {
                state.heldResponse = nil
                state.heldCompletion = nil
            }
            return (state.heldResponse, state.heldCompletion)
        }
        if let held {
            client.urlProtocol(self, didReceive: held.response, cacheStoragePolicy: .notAllowed)
            held.completionHandler(.allow)
        }
        if let completion { deliverCompletion(completion.error) }
    }

    func forwardedTask(didFinishCollecting metrics: URLSessionTaskMetrics) {
        let timings = NetworkEntry.Timings(metrics: metrics)
        let networkProtocol = metrics.transactionMetrics.last?.networkProtocolName
        state.withLockUnchecked { state in
            state.timings = timings
            state.networkProtocol = networkProtocol
        }
    }

    func forwardedTask(didCompleteWithError error: (any Error)?) {
        let snapshot = state.withLockUnchecked { state in
            state.pump?.cancel()
            let snapshot = state
            state.isCompleted = true
            if state.redirect == .pending, !state.isStopped { state.heldCompletion = HeldCompletion(error: error) }
            return snapshot
        }
        // A stop means the app no longer listens.
        guard !snapshot.isStopped else { return }
        switch snapshot.redirect {
        case .pending:
            // Passed on if the app's session refuses the redirect.
            return
        case .refused:
            // The redirect already ended the entry.
            deliverCompletion(error)
        case .none:
            if let logger = snapshot.logger, let entryID = snapshot.entryID {
                if let pump = snapshot.pump {
                    logger.updateRequestBodySize(entryID, byteCount: pump.bytesWritten)
                }
                logger.finish(
                    entryID, bodyPrefix: snapshot.responseBody, bodyByteCount: snapshot.responseByteCount,
                    error: error, timings: snapshot.timings, networkProtocol: snapshot.networkProtocol)
            }
            deliverCompletion(error)
        }
    }

    private func deliverCompletion(_ error: (any Error)?) {
        deliver { protocolInstance, client in
            if let error {
                client.urlProtocol(protocolInstance, didFailWithError: error)
            } else {
                client.urlProtocolDidFinishLoading(protocolInstance)
            }
        }
    }

    /// The request body stream failed while it was being sent on.
    private func failForwarding(with error: any Error) {
        let (logger, entryID, task) = state.withLockUnchecked { state in
            state.isStopped = true
            return (state.logger, state.entryID, state.task)
        }
        task?.cancel()
        if let logger, let entryID { logger.finish(entryID, bodyPrefix: Data(), bodyByteCount: 0, error: error) }
        deliver(ignoringStop: true) { protocolInstance, client in
            client.urlProtocol(protocolInstance, didFailWithError: error)
        }
    }

    // MARK: Client thread

    /// Runs `action` with the client on the thread that started loading, unless loading stopped.
    private func deliver(ignoringStop: Bool = false, _ action: @escaping (CaptureProtocol, any URLProtocolClient) -> Void) {
        let delivery = Delivery { [weak self] in
            guard let self, let client = self.client else { return }
            if !ignoringStop, self.state.withLockUnchecked({ $0.isStopped }) { return }
            action(self, client)
        }
        guard let clientThread else {
            delivery.run()
            return
        }
        delivery.perform(#selector(Delivery.run), on: clientThread, with: nil, waitUntilDone: false, modes: runLoopModes)
    }
}

/// A block that can be scheduled on another thread's run loop with `perform(_:on:with:waitUntilDone:modes:)`.
private final class Delivery: NSObject, @unchecked Sendable {
    private let block: () -> Void

    init(_ block: @escaping () -> Void) {
        self.block = block
    }

    @objc func run() {
        block()
    }
}

extension NetworkEntry.Timings {
    /// Phase durations of the last transaction (the one that produced the response).
    init(metrics: URLSessionTaskMetrics) {
        self.init()
        guard let transaction = metrics.transactionMetrics.last else { return }
        func span(_ start: Date?, _ end: Date?) -> TimeInterval? {
            guard let start, let end else { return nil }
            return max(0, end.timeIntervalSince(start))
        }
        domainLookup = span(transaction.domainLookupStartDate, transaction.domainLookupEndDate)
        connect = span(transaction.connectStartDate, transaction.connectEndDate)
        secureConnection = span(transaction.secureConnectionStartDate, transaction.secureConnectionEndDate)
        send = span(transaction.requestStartDate, transaction.requestEndDate)
        wait = span(transaction.requestEndDate, transaction.responseStartDate)
        receive = span(transaction.responseStartDate, transaction.responseEndDate)
    }
}
