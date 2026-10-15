<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-light.svg" alt="iOSDevelopmentTools: Inspect your app's network requests, logs and device state in an in-app console, with secrets redacted."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="Latest version: v1.0.0"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="Supported platforms: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="Language version: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="License: MIT"></picture></a>
</p>

<p align="center">
<a href="#quick-start"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-en-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-en-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-en-light.svg" alt="Get started"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-en-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-en-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-en-light.svg" alt="Documentation"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-en-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-en-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-en-light.svg" alt="Examples"></picture></a>
</p>

<!-- brand:end -->

A Swift package that puts a debugging console inside your iOS or macOS app. It records the
requests your app makes with `URLSession`, keeps your log messages and collects a device report,
and shows all three in a SwiftUI console that opens with a shake, a button or a window. Open a
request to see its headers, bodies and timings, or share it as a cURL command or a HAR file for
browser developer tools, Charles or Proxyman. Passwords, tokens, cookies and API keys are
replaced before anything is stored, so they do not end up in the console, an exported file or a
screenshot in a bug report. It is meant for debug and test builds, has no dependencies and is
written for Swift 6 strict concurrency.

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="The Network tab listing seven real requests from the example app: a failed request to an unknown host, a 503, a 404 and four successful requests with their duration and size"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="A sign-in request opened in the console: the Authorization header and the password in the JSON body show [REDACTED]"></picture>
</p>

## Highlights

- **One line to record** — `NetworkCapture.start()` records `URLSession.shared` and every
  session created from the default or ephemeral configuration afterwards, including libraries
  built on `URLSession`. Your app receives every response unchanged.
- **Redaction before storage** — header, query, form, multipart and JSON values with sensitive
  names are replaced, however the name is spelled (`X-API-Key`, `api_key`, `API%5FKEY`). A JSON
  body that cannot be checked, for example because it was cut off, is withheld instead of stored
  unchecked.
- **Fixed memory use** — at most 500 requests and 256 KiB of each body by default, log messages
  in a ring buffer, and uploads over 4 MiB streamed instead of copied.
- **Export** — any request as a shell-safe `curl` command, any list of requests as an HTTP
  Archive (HAR 1.2).
- **Logs and device report** — `LogStore` keeps leveled, categorized messages and also writes
  them to the unified logging system; `DeviceSnapshot` reports version, OS, model, memory
  footprint, thermal state and whether a debugger is attached.
- **Tested** — 103 Swift Testing tests on macOS and 104 on an iOS simulator. Requests travel
  from an app session through the capture to a stub server, and the tests check what the server
  received, what the app received and what was stored.

## Quick start

**1. Add the package**

In Xcode, choose **File › Add Package Dependencies…** and enter the repository URL:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Paste it into the search field at the top right of the window. Leave **Dependency Rule** at
**Up to Next Major Version** from `2.0.0`, then click **Add Package**. In the next window, choose
your app target next to **iOSDevelopmentTools** and click **Add Package** again.

**2. Import the module**

```swift
import iOSDevelopmentTools
```

Put this line at the top of the file that declares your `App`, below `import SwiftUI`.

**3. Start recording and add the console**

In your app's `App` file, start capture in `init` and add the console to the root view. The
`#if DEBUG` lines keep both out of release builds:

```swift
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

Run the app on an iPhone simulator, let it make a request, and choose **Device › Shake** in the
Simulator menu. The console opens on the Network tab with the request in the list.

## Installation

### Swift Package Manager

In Xcode, choose **File › Add Package Dependencies…** and enter the repository URL:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Or add it to the `dependencies` in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOSDevelopmentTools.git", from: "2.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "iOSDevelopmentTools", package: "iOSDevelopmentTools")
    ])
]
```

## Usage

The samples below are copied from
[ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift), which the example
app and the test suite compile.

### Open the console from a button

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### Record a session you create yourself

Sessions created after `NetworkCapture.start()` from `.default` or `.ephemeral` are recorded
automatically. For a session created earlier, add recording to its configuration:

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### Choose what is kept

Limits outside their ranges are clamped. Name fragments are matched against normalized names, so
`"iban"` also catches `IBAN`, `iban_number` and `ibanNumber`:

```swift
func configureNetworkLogger() {
    NetworkLogger.shared.configuration = NetworkLogger.Configuration(
        maximumEntries: 1_000,
        maximumBodySize: 512 * 1024,
        redaction: RedactionPolicy(nameFragments: RedactionPolicy.defaultNameFragments + ["iban", "ssn"]),
        ignoredHosts: ["analytics.example.com"]
    )
}
```

### Log messages

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### Export requests and reports

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

The console's share menus do the same for the user: **Export HAR** in the Network tab, **Share as
cURL** in a request, **Share Report** in the Device tab.

### Use it on macOS

A Mac app has no shake. Give the console a window of its own and open it with a shortcut:

```swift
struct MacDebugScenes: Scene {
    var body: some Scene {
        Window("Developer Tools", id: "devtools") {
            DevToolsConsole()
        }
        .keyboardShortcut("d", modifiers: [.command, .option])
    }
}
```

## Demo

<table>
<tr>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="The Logs tab with info, warning and error messages from the example app, each with its category, time and source line"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="The Device tab showing app version, iOS version, simulated model, memory, app memory, thermal state, Low Power Mode and debugger status"></picture></td>
</tr>
</table>

The screenshots come from the [example app](Examples) on an iPhone 17 Pro simulator with iOS 27,
captured by [`scripts/capture-screens.sh`](scripts/capture-screens.sh). The requests are real:
the app sends them to `api.github.com` and `postman-echo.com`. To run it, open
`Examples/DevToolsDemo/DevToolsDemo.xcodeproj`, choose an iPhone simulator or **My Mac**, run,
and tap **Send All**.

## Documentation

Reference documentation and articles:

- [API reference](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — every public type with its parameters and limits.

## Guides

- [Getting started](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — add the package, start capture, open the console, log messages.
- [Capturing network traffic](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — which sessions are recorded, how requests reach the server, memory limits, what is not
  recorded.
- [Redacting sensitive data](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — how names are matched, what is replaced, why some bodies are withheld, and the limits.
- [Keeping the tools out of release builds](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — compilation conditions and a separate internal target.

## Requirements

| Platform | Minimum version |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| Toolchain | Swift 6.2 · Xcode 26+ |

The shake gesture is iOS only; on macOS the console opens in a window or a sheet.

## Architecture

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture` registers `CaptureProtocol`, a `URLProtocol`, for `URLSession.shared` and adds
  it to the default and ephemeral configurations. The protocol sends each request on through one
  internal `URLSession` and calls the app's session back on the thread that started the load.
- `RedactionPolicy` runs before a `NetworkEntry` is created, so stores and exports only ever see
  redacted values.
- `NetworkLogger` and `LogStore` are lock-protected ring buffers that publish changes through an
  `AsyncStream`; the console's observable models read them at most about seven times a second.
- Everything outside the console views is `Sendable` and callable from any thread.

## Roadmap

Planned, in no fixed order: keeping requests across launches, a `swift-log` backend for
`LogStore`, tvOS and visionOS support for the console, and request mocking. Suggestions are
welcome in [issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues).

## Contributing

Contributions are welcome. Read the [contributing guide](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md) and the [code of conduct](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md) before opening a pull request. Report security issues privately as described in the [security policy](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md).

## License

Released under the MIT license. See [LICENSE](LICENSE).
