import Foundation

/// How ``CaptureProtocol`` passes a redirect to the app's session.
extension CaptureProtocol {
    /// How long after reporting a redirect the app's session is given to follow it, by stopping
    /// this load, before the redirect counts as refused and its response is passed on.
    static let redirectDecisionTime: DispatchTimeInterval = .milliseconds(500)

    /// Where a redirect stands. The app's session follows a redirect by stopping this load and
    /// starting a new one; it gives no signal when its delegate refuses one.
    enum Redirect {
        case none
        /// Reported to the app's session, which has not stopped this load yet.
        case pending
        /// Not followed in time: the redirect response goes to the app as the final response.
        case refused
    }

    /// A forwarded response held back while a redirect is pending, with the forwarding
    /// session's disposition handler, which is called once the redirect is followed or refused.
    struct HeldResponse {
        let response: URLResponse
        let completionHandler: @Sendable (URLSession.ResponseDisposition) -> Void
    }

    /// The end of the forwarded task, held back while a redirect is pending.
    struct HeldCompletion {
        let error: (any Error)?
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
}
