# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Redaction now follows one shared specification instead of a patch per reported bypass. The rule:
what the policy does not fully understand is hidden, never shown. Redaction is a safety net, not
a guarantee; keep secrets out of logs in the first place.

### Security

- Keys (JSON fields, query, form and multipart names, header names, `key=value` in text) are
  folded first: percent, `\u` and `&#` escapes are decoded, then NFKC, case folding, and `_`, `-`,
  `.` and spaces are removed. Only a key that is then plain ASCII letters and digits is compared
  with the secret names. Any other key (look-alike letters from another script, format characters
  such as ZWJ or a soft hyphen, combining marks, other separators) has its value hidden. A key
  that matches hides its whole value, whatever its type.
- Bodies are parsed, never scanned by hand: JSON with `JSONSerialization`, redacted on the parsed
  tree and serialized again (so of a repeated key only the value the parse kept is stored), forms
  with the platform's percent decoding, multipart with a strict RFC 2046 parser that always omits
  file parts. A body with an unknown or missing content type, one that does not parse, one that
  was cut off, one over 1 MiB and JSON in a charset other than UTF-8, UTF-16 or UTF-32 is
  replaced by a note such as `[body omitted: 512 bytes, application/xml]`. In 2.0.0, plain-text,
  XML and other bodies were stored unchecked.
- Headers keep their values only when they are on an allowlist (by default `Accept`,
  `Accept-Encoding`, `Accept-Language`, `Cache-Control`, `Content-Encoding`, `Content-Length`,
  `Content-Type`, `ETag` and `User-Agent`). `Authorization`, `Proxy-Authorization`, `Cookie`,
  `Set-Cookie`, `X-Api-Key` and names with `token`, `secret`, `key`, `auth`, `session` or
  `signature` stay hidden when listed.
- URLs lose their user info and fragment. Query values are hidden unless the parameter is on an
  allowlist, which is empty by default. Path segments that look like identifiers or secrets
  (UUIDs, numbers of six or more digits, long hex or Base64, JWTs, mixed tokens of 16 or more
  characters) become `:id`.
- Values of other keys, kept header values and free text are scanned for JWTs, bearer
  credentials, hex or Base64 strings of 32 or more characters, card numbers (Luhn), IBANs
  (mod 97) and email addresses.
- `LogStore` messages and the error descriptions of failed requests are redacted with the
  free-text rule: `key=value`, `key: value` and `"key":"value"` follow the key rule, a secret word
  without `=` or `:` hides the rest of the line, a key and its value on two lines are both found,
  and U+2028, U+2029, U+0085, vertical tab and form feed are folded to line feeds first.

### Added

- `RedactionPolicy(additionalSecretNames:allowedHeaders:allowedQueryParameters:urlDetail:)`,
  `redact(text:)`, `URLDetail` (`.hostOnly` records only scheme, host and port),
  `defaultSecretNames`, `defaultAllowedHeaders`, `secretNames`, `allowedHeaders`,
  `allowedQueryParameters` and `LogStore.Configuration.redaction`.
- A test for each bypass class of the specification, property tests with generated obfuscations
  of every secret name and generated secrets, and tests that ordinary keys, allowlisted headers
  and log lines are kept. Every bypass reported against 2.0.0 is kept as a test. 158 tests run on
  macOS.

### Changed

- `RedactionOutcome.withheld` is now `.omitted`, and an omitted body stores the note in place of
  its bytes. The console, HAR files and cURL commands say why a body is missing.
- Secret names replace name fragments: a name of five or more letters matches anywhere in a
  folded key, a shorter one (`key`, `pin`, `sid`) as one of its words or at its end, so
  `keyboard` keeps its value while `author` no longer matches `auth`.

### Deprecated

- `RedactionPolicy(nameFragments:withholdsUncheckedBodies:)`,
  `RedactionPolicy(withholdsUncheckedBodies:)`, `defaultNameFragments`, `nameFragments`,
  `withholdsUncheckedBodies` and `RedactionOutcome.withheld`. They still build and map to the new
  rules; an empty fragment list and `withholdsUncheckedBodies: false` no longer weaken redaction.

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
  `URLSessionTaskMetrics` timings are recorded. A redirect that the app's session refuses
  returns the redirect response, half a second after it arrives.
- `NetworkLogger` stores the requests in a ring buffer with clamped limits (1–10,000 entries,
  0–16 MiB per body), can ignore hosts and their subdomains, accepts manual records for traffic
  capture cannot see, and publishes changes through an `AsyncStream`.
- `RedactionPolicy` replaces sensitive values before anything is stored: headers by name and by
  authentication scheme, query, fragment and matrix parameters, URL user info, JSON keys at any
  depth (also inside strings that hold JSON, and inside form and URL parameter values that decode to
  JSON), form fields (also in bodies sent without a `Content-Type`, and in JSON bodies sent as a
  form, which are checked both ways) and multipart fields. Names are normalized (case, separators,
  percent-encoding, invisible characters, NFKC compatibility forms such as full-width letters)
  before they are matched. Structured bodies that cannot be checked (cut off, malformed, nested
  deeper than 64 levels, multipart with more than 1,000 parts, with text outside its boundaries,
  with bare CR or LF line breaks, with a line that starts with the boundary and goes on, with more
  than one boundary parameter, with a folded part header, with a name split into RFC 2231 pieces,
  with a malformed header parameter or header name, or with a boundary outside the RFC 2046
  characters) are withheld. JSON is also recognized in UTF-16 and UTF-32, with or without a byte
  order mark.
  Separators are found in the UTF-8 bytes, so a combining mark after one cannot hide it.
  Parameters are checked both as split on `&` alone, as Python and `URLSearchParams` read them,
  and as split on `&` and `;`. JSON in
  which an object repeats a key is withheld, because parsers differ in which value they keep.
- `NetworkEntry.curlCommand()` and `HTTPArchive` export requests as shell-safe `curl` commands
  and as HAR 1.2 files.
- `LogStore` keeps leveled, categorized log messages in a ring buffer and writes them to the
  unified logging system; messages and categories are cut off at a number of Unicode scalars, so
  combining marks cannot stretch them; `LogFilter` filters them.
- `DeviceSnapshot` reports app version, OS, model, memory and memory footprint, thermal state,
  Low Power Mode, attached debugger, locale and uptime.
- `DevToolsConsole`, a SwiftUI console with Network, Logs and Device tabs, search, filters and
  share menus; `NetworkEntryView` for one request; `devToolsConsole(isPresented:)` and, on iOS,
  `devToolsConsoleOnShake()`.
- DocC documentation with four articles, and the DevToolsDemo example app for iOS and macOS.
- 148 Swift Testing tests that run on macOS, and 149 on an iOS simulator, including end-to-end
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
