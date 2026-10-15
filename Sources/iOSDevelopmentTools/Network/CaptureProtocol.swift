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
        var isRedirected = false
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
        let (task, pump, logger, entryID, ended) = state.withLockUnchecked { state in
            let ended = state.isStopped || state.isRedirected || state.isCompleted
            state.isStopped = true
            return (state.task, state.pump, state.logger, state.entryID, ended)
        }
        pump?.cancel()
        task?.cancel()
        guard !ended else { return }
        // The app cancelled the request; the forwarded task's own completion is ignored now.
        if let logger, let entryID {
            logger.finish(entryID, bodyPrefix: Data(), bodyByteCount: 0, error: URLError(.cancelled))
        }
    }

    // MARK: Forwarded task callbacks (on the forwarding session's queue)

    func forwardedTask(didReceive response: URLResponse) -> URLSession.ResponseDisposition {
        let (logger, entryID, ended) = state.withLockUnchecked { ($0.logger, $0.entryID, $0.isRedirected || $0.isStopped) }
        guard !ended else { return .cancel }
        if let logger, let entryID { logger.receive(response: response, for: entryID) }
        deliver { protocolInstance, client in
            client.urlProtocol(protocolInstance, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        return .allow
    }

    func forwardedTask(didReceive data: Data) {
        let ended = state.withLockUnchecked { state -> Bool in
            guard !state.isRedirected, !state.isStopped else { return true }
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

    func forwardedTask(willRedirectWith response: HTTPURLResponse, to request: URLRequest) -> URLRequest? {
        guard let redirect = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return request }
        // The redirected request goes back through the app's session, which captures it again.
        URLProtocol.removeProperty(forKey: Self.handledKey, in: redirect)
        let (logger, entryID, task) = state.withLockUnchecked { state in
            state.isRedirected = true
            return (state.logger, state.entryID, state.task)
        }
        if let logger, let entryID { logger.redirect(entryID, response: response, to: redirect as URLRequest) }
        task?.cancel()
        let redirectRequest = redirect as URLRequest
        // As in Apple's CustomHTTPProtocol: report the redirect, then end this load; the app's
        // session starts the redirected request itself.
        deliver(ignoringStop: true) { protocolInstance, client in
            client.urlProtocol(protocolInstance, wasRedirectedTo: redirectRequest, redirectResponse: response)
            client.urlProtocol(protocolInstance, didFailWithError: CocoaError(.userCancelled))
        }
        return nil
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
            return snapshot
        }
        // A redirect already ended this request; a stop means the app no longer listens.
        guard !snapshot.isRedirected, !snapshot.isStopped else { return }
        if let logger = snapshot.logger, let entryID = snapshot.entryID {
            if let pump = snapshot.pump {
                logger.updateRequestBodySize(entryID, byteCount: pump.bytesWritten)
            }
            logger.finish(
                entryID, bodyPrefix: snapshot.responseBody, bodyByteCount: snapshot.responseByteCount,
                error: error, timings: snapshot.timings, networkProtocol: snapshot.networkProtocol)
        }
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
