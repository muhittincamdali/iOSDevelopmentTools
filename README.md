<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-light.svg" alt="iOSDevelopmentTools: Inspect your app's network requests, logs and device state in an in-app console, with secrets redacted."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="Latest version: v2.1.1"></picture></a>
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
- **Redaction before storage** — values under secret names (`password`, `token`, `api_key`,
  however they are spelled or escaped) and under keys that are not plain ASCII are replaced, and
  only allowlisted headers and query parameters keep their values. JSON, form and multipart
  bodies are parsed; a body that cannot be parsed is replaced by a note instead of being stored.
  In a log message, everything from the first secret name, or key that is not on the allowlist,
  to its end is hidden.
- **Bounded storage** — at most 500 requests and 256 KiB of each body by default, log messages
  in a ring buffer, and uploads over 4 MiB streamed instead of copied. Headers and URLs are
  stored whole.
- **Export** — any request as a shell-safe `curl` command, any list of requests as an HTTP
  Archive (HAR 1.2).
- **Logs and device report** — `LogStore` keeps leveled, categorized messages and also writes
  them to the unified logging system; `DeviceSnapshot` reports version, OS, model, memory
  footprint, thermal state and whether a debugger is attached.
- **Tested** — 873 Swift Testing tests on macOS and 870 on an iOS simulator. Requests travel
  from an app session through the capture to a stub server, and the tests check what the server
  received, what the app received and what was stored.

## Quick start

**1. Add the package**

In Xcode, choose **File › Add Package Dependencies…** and enter the repository URL:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Paste it into the search field at the top right of the window. Leave **Dependency Rule** at
**Up to Next Major Version** from `2.1.2`, then click **Add Package**. In the next window, choose
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

`devToolsConsoleOnShake()` is available on iOS only. In an app that also builds for macOS,
write `#if DEBUG && os(iOS)` around it instead, and give the console a window as shown in
**Use it on macOS** below.

## Installation

### Swift Package Manager

In Xcode, choose **File › Add Package Dependencies…** and enter the repository URL:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Or add it to the `dependencies` in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOSDevelopmentTools.git", from: "2.1.2")
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

Limits outside their ranges are clamped. Secret names are folded like the keys they are compared
with, so `"license_number"` also catches `licenseNumber` and `LICENSE-NUMBER`, and only the
listed query parameters keep their values:

```swift
func configureNetworkLogger() {
    NetworkLogger.shared.configuration = NetworkLogger.Configuration(
        maximumEntries: 1_000,
        maximumBodySize: 512 * 1024,
        redaction: RedactionPolicy(additionalSecretNames: ["license_number"], allowedQueryParameters: ["page"]),
        ignoredHosts: ["analytics.example.com"]
    )
}
```

### What is recorded

- **Recorded:** method, status, timings, header names, the values of allowlisted headers (by
  default `Accept`, `Accept-Encoding`, `Accept-Language`, `Cache-Control`, `Content-Encoding`,
  `Content-Length`, `Content-Type`, `ETag` and `User-Agent`), the URL's scheme, host, path and
  query parameter names, and JSON, form, multipart and `text/plain` bodies after redaction.
- **Never recorded:** URL user info and fragments, query values that are not allowlisted, the
  values of all other headers (`Authorization`, `Cookie` and `Set-Cookie` even when allowlisted),
  values under secret names such as `password`, `token` or `api_key`, path segments that look
  like identifiers (shown as `:id`) and the segment after one that names a secret or is not plain
  ASCII (`/caf%C3%A9/menu` is kept as `/caf%C3%A9/:id`), the path and query of a URL
  whose path has a dot segment, a `;` or an escaped `.`, `/`, `\`, `;` or `%` (`/pin/./4831`,
  `..`, `/cart;jsessionid=…`, `%2E`, `%2F`, `%5C`, `%3B`, `%25`: only the scheme and host are
  kept, so matrix parameters are never parsed), a host that names a secret with everything after
  it (`myapp://pin/4831` and `myapp://pin-4831` are kept as `myapp://[REDACTED]`; a host such as
  `auth.example.com` is hidden too), file parts of multipart bodies, and the values of multipart
  part headers other than `Content-Length` and `Content-Transfer-Encoding` (`Content-ID` and four
  other `Content-*` names keep their name; any other part header, such as `User-Agent`, is stored
  as `[REDACTED]: [REDACTED]`), and any value of those two outside their form: a
  `Content-Length` other than ASCII digits and a `Content-Transfer-Encoding` other than `7bit`,
  `8bit`, `binary`, `base64` or `quoted-printable` (kept in lowercase) are stored as `[REDACTED]`
  (`Content-Length: pin-4831` as `Content-Length: [REDACTED]`).
- **Keys that are not plain ASCII** once escapes are decoded, NFKC is applied and case is folded
  (`pаssword` with a Cyrillic `а`, `pass\u200Dword`, `şifre`) have their values hidden by default.
- **Bodies that cannot be parsed** (an unknown or missing content type, malformed JSON or
  multipart, a body cut off at the size limit) are replaced by a note such as
  `[body omitted: 512 bytes, application/xml]`.
- **Log messages** are kept up to their first trigger: a secret name, a key that is not on the
  allowlist (`status`, `method`, `path`, `duration_ms` and `count` by default; add yours with
  `allowedTextKeys`), a character outside ASCII that is not a letter, mark or digit (`꞉`, `…`,
  an emoji, a space such as U+00A0, or a letter that compatibility normalization reads as
  punctuation, such as `🄁` read as `0,`), a word that mixes scripts (`tоken` with a Cyrillic
  `о`), an escape of any form, cut at the start of its word (a backslash before anything but
  white space, `%3D`, `&` before a letter or `#`: `R&D`, `&amp`; an `&` that starts a field, as
  in `status=200&count=3`, is no escape), a key in quotes that is not allowed (cut at its
  opening quote: `"x":"hunter2"` is stored as `[REDACTED]`), markup (a `<` that is not a
  comparison: `<b>`, `</x>`, `<!--`; no tag keeps its text), a quote that does not close on its
  line, quotes that overlap (`'x "y' z"`) or a bracket that does not close hides everything
  after it, the lines below too
  (`login password=hunter2 status=200` is stored as `login password=[REDACTED]`, `x=hunter2` as
  `x=[REDACTED]`). A message with no trigger is kept as it is, apart from detected tokens, card
  numbers and email addresses.
  The detectors read across VT, FF, U+0085, U+2028 and U+2029, which cut a message, so a card
  number, IBAN, email address or token split by one is hidden from its start
  (`paid 4111 1111 1111`, U+2028, `1111` is stored as `paid [REDACTED]`); LF and CR end a finding.
- **URLs in log messages** have no island logic. A URL stays visible only when it is clean:
  `scheme://host` with an optional path of ASCII letters, digits, `.`, `_`, `-` and `/`, no host or
  path segment that names a secret, and after it a space, a line end, the end of the text, or one
  `.`, `,`, `!` or `)` followed by one of those. Any other URL (a query, a fragment, a port, user
  info, an escape such as `%3D`, a quote or two marks after it) hides the message from where the
  URL starts (`GET https://api.example.com/v1/items?page=2 done` is stored as `GET [REDACTED]`);
  `allowedQueryParameters` applies to recorded request URLs, not to URLs in text.

Redaction is a safety net, not a guarantee. It is built for secrets recorded by accident:
structured input is parsed, and what the parser does not fully understand is hidden; free text is a
best effort, and a secret name written without `=` or `:` with two or more of its letters replaced
by look-alikes (`pɑsswoʀd hunter2`) is not guaranteed to be found; one letter, mark or number
with no ASCII form counts as any letter, so `tͦken hunter2`,
`passw〇rd hunter2` and `t၀ken hunter2` (a Myanmar zero) are found.
Keep secrets out of the requests you record and out of log messages in the first place, and prefer
structured logging.

Three more limits belong to that model. **Cost bound:** all the documents nested in one input
(JSON in a string, a URL in text) read at most four times the input's length together; past that
budget, the string that holds the next document is hidden whole. **Length bound:** a text longer
than 2^28 − 1 Unicode scalars (268,435,455) is not read and is hidden whole. **Multi-line layouts** need
nothing special: a property list `<key>` on its own line, JSON spread over several lines and a
multipart body written as text are hidden from the first trigger to the end of the text, so the
value is hidden wherever it is written.

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
  — what is recorded and what is never recorded, how keys are matched, why some bodies are
  omitted, and the limits.
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
