# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-10-15

A new package with a new API: an in-app network inspector, log console and device report. The
1.0.0 code (a network client built on Alamofire, storage, analytics and logging managers and
utility extensions) was removed in June 2026 and replaced with placeholders: a network
interceptor whose `URLProtocol` never sent the request, so every intercepted request hung, a
swizzling check that always returned `false`, a `SecureStorage` wrapper that wrote "sensitive"
values to `UserDefaults`, and circuit-breaker, retry and event-bus types unrelated to
development tools. None of that is kept. Because every public name changes, this release is a
new major version.

### Added

- `NetworkCapture` records the HTTP and HTTPS requests of `URLSession.shared` and of every
  session created from the default or ephemeral configuration after `start(logger:)`;
  `install(into:)` adds recording to any other configuration. Requests are sent on unchanged and
  responses reach the app unchanged; redirects, cancellations, errors and
  `URLSessionTaskMetrics` timings are recorded.
- `NetworkLogger` stores the requests in a ring buffer with clamped limits (1–10,000 entries,
  0–16 MiB per body), can ignore hosts and their subdomains, accepts manual records for traffic
  capture cannot see, and publishes changes through an `AsyncStream`.
- `RedactionPolicy` replaces sensitive values before anything is stored: headers by name and by
  authentication scheme, query, fragment and matrix parameters, URL user info, JSON keys at any
  depth (also inside strings that hold JSON), form fields (also in bodies sent without a
  `Content-Type`) and multipart fields. Names are normalized (case, separators,
  percent-encoding, invisible characters) before they are matched. Structured bodies that cannot
  be checked (cut off, malformed, nested deeper than 64 levels, multipart with more than 1,000
  parts, with text outside its boundaries, with bare CR or LF line breaks or with a line that
  starts with the boundary and goes on) are withheld.
- `NetworkEntry.curlCommand()` and `HTTPArchive` export requests as shell-safe `curl` commands
  and as HAR 1.2 files.
- `LogStore` keeps leveled, categorized log messages in a ring buffer and writes them to the
  unified logging system; `LogFilter` filters them.
- `DeviceSnapshot` reports app version, OS, model, memory and memory footprint, thermal state,
  Low Power Mode, attached debugger, locale and uptime.
- `DevToolsConsole`, a SwiftUI console with Network, Logs and Device tabs, search, filters and
  share menus; `NetworkEntryView` for one request; `devToolsConsole(isPresented:)` and, on iOS,
  `devToolsConsoleOnShake()`.
- DocC documentation with four articles, and the DevToolsDemo example app for iOS and macOS.
- 121 Swift Testing tests that run on macOS, and 122 on an iOS simulator, including end-to-end
  capture through a stub server, redaction bypass attempts, and NaN, infinite and out-of-range
  inputs to every conversion.

### Changed

- Requires Swift 6.2 (Xcode 26), iOS 17 and macOS 14. watchOS and tvOS are no longer listed.
- No dependencies; the Alamofire, SwiftLint, Quick and Nimble dependencies of 1.0.0 are gone.

### Removed

- The 1.0.0 modules (`NetworkTools`, `StorageTools`, `AnalyticsTools`, `DebugTools`,
  `UtilityTools`) and the June 2026 placeholders described above.
- The CocoaPods podspec; the pod was never published to trunk.

## [1.0.0] - 2026-02-03

First tagged release: a network client built on Alamofire, storage, analytics and logging
managers and utility extensions in five modules, each also offered as its own library.

[Unreleased]: https://github.com/muhittincamdali/iOSDevelopmentTools/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/muhittincamdali/iOSDevelopmentTools/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/muhittincamdali/iOSDevelopmentTools/releases/tag/v1.0.0
