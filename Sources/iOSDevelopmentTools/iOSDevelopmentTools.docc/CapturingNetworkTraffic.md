# Capturing network traffic

Learn which requests are recorded, how they reach the server, and what the limits are.

## Overview

``NetworkCapture`` records requests with a `URLProtocol`. Once ``NetworkCapture/start(logger:)``
has run, the protocol sees the requests of:

- `URLSession.shared`,
- every session created afterwards from `URLSessionConfiguration.default` or `.ephemeral`,
- any session whose configuration went through ``NetworkCapture/install(into:)``.

Libraries built on `URLSession`, such as Alamofire, are recorded the same way.

### What happens to a request

1. The protocol copies the request, redacts the copy's URL, headers and body with the logger's
   ``RedactionPolicy``, and adds a ``NetworkEntry`` to the ``NetworkLogger``.
2. It sends the original request on through an internal session with the default
   configuration. The server receives exactly what the app sent.
3. As the response arrives, the protocol passes it back to the app's session unchanged and keeps
   a redacted copy of at most ``NetworkLogger/Configuration/maximumBodySize`` bytes. A longer
   body cannot be parsed whole, so its entry holds a note such as
   `[body omitted: 300000 bytes, application/json]` instead.
4. When the request ends, the entry gets its status, error and the phase timings from
   `URLSessionTaskMetrics`.

Redirects are reported to the app's session, which sends the next request itself, so each hop is
its own entry. When the session's delegate refuses a redirect, the session gives no signal, so the
redirect response and its body reach the app half a second later, once capture has waited for the
session to follow it. Cancelling a task records a cancellation.

### Memory use

A logger keeps at most ``NetworkLogger/Configuration/maximumEntries`` entries (500 by default)
and at most ``NetworkLogger/Configuration/maximumBodySize`` bytes of each body (256 KiB by
default); with redaction on, a body over that limit, or over
``RedactionPolicy/maximumCheckedBodySize`` (1 MiB), is replaced by a note. Request bodies up to 4 MiB are read into memory to be sent on; larger uploads are
streamed in 64 KiB chunks, so the size of an upload does not change how much memory capture uses.
Headers and URLs are stored whole; no limit applies to them.

```swift
NetworkLogger.shared.configuration = NetworkLogger.Configuration(
    maximumEntries: 1_000,
    maximumBodySize: 512 * 1024,
    redaction: RedactionPolicy(additionalSecretNames: ["license_number"], allowedQueryParameters: ["page"]),
    ignoredHosts: ["analytics.example.com"]
)
```

Values outside the allowed ranges are clamped: 1 to 10,000 entries and 0 to 16 MiB per body.

### Sessions created before capture starts

A session copies its configuration when it is created, so a session made before
``NetworkCapture/start(logger:)`` is not recorded. Start capture first, or add recording to the
configuration yourself:

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### What is not recorded

- **Background sessions.** The system runs their transfers outside the app, where no
  `URLProtocol` can see them. Record them yourself in the session delegate with
  ``NetworkLogger/record(request:response:body:error:startDate:endDate:)``.
- **WebSocket tasks** and other schemes than `http` and `https`.
- **Hosts in** ``NetworkLogger/Configuration/ignoredHosts``, and their subdomains. Their requests
  go out as usual.

### Settings that do not carry over

Recorded requests are sent by an internal session, so settings that belong to your session
rather than to the request do not apply to them: your session delegate's handling of
authentication challenges and server trust (certificate pinning), `waitsForConnectivity`, and a
custom `URLCache` or cookie storage. The request's own URL, method, headers, body, cache policy
and timeout do apply. If your app depends on one of these session settings, ignore that host or
call ``NetworkCapture/stop()`` while you test it.

## See Also

- <doc:RedactingSensitiveData>
- ``HTTPArchive``
