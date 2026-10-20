# ``iOSDevelopmentTools``

Record your app's network requests and log messages and inspect them in an in-app console, with
secrets redacted before anything is stored.

## Overview

iOSDevelopmentTools is a debugging toolkit for SwiftUI apps on iOS 17+ and macOS 14+, with no
dependencies. One call, ``NetworkCapture/start(logger:)``, records every request your app makes
with `URLSession`. ``LogStore`` keeps your log messages, and ``DeviceSnapshot`` collects the
facts a bug report needs. ``DevToolsConsole`` shows all three in the app: search and filter the
requests, open one to see its headers, bodies and timings, and share it as a cURL command or an
HTTP Archive (HAR) file that browser developer tools, Charles and Proxyman open.

Passwords, tokens, cookies and API keys are replaced by ``RedactionPolicy`` before a request is
stored or a message is logged, so they do not reach the console, an exported file or a
screenshot. Only allowlisted headers and query parameters keep their values, a body that cannot
be parsed is left out, and a log message is hidden from its first secret name to its end. Redaction is a safety net, not a guarantee: keep secrets out of
logs in the first place. The app itself still receives every response unchanged.

```swift
import iOSDevelopmentTools
import SwiftUI

@main
struct MyApp: App {
    init() {
        #if DEBUG
        NetworkCapture.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if DEBUG
                .devToolsConsoleOnShake()
                #endif
        }
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:CapturingNetworkTraffic>
- <doc:RedactingSensitiveData>
- <doc:KeepingToolsOutOfReleaseBuilds>

### Recording requests

- ``NetworkCapture``
- ``NetworkLogger``
- ``NetworkEntry``
- ``HTTPHeader``
- ``CapturedBody``
- ``NetworkError``

### Redaction

- ``RedactionPolicy``
- ``RedactionOutcome``

### Exporting

- ``HTTPArchive``
- ``NetworkEntry/curlCommand()``

### Logging

- ``LogStore``
- ``LogEntry``
- ``LogLevel``
- ``LogFilter``

### Diagnostics

- ``DeviceSnapshot``

### Console

- ``DevToolsConsole``
- ``NetworkEntryView``
- ``NetworkFilter``
- ``SwiftUICore/View/devToolsConsole(isPresented:networkLogger:logStore:)``
- ``SwiftUICore/View/devToolsConsoleOnShake(networkLogger:logStore:)``
- ``Foundation/NSNotification/Name/devToolsDeviceDidShake``
