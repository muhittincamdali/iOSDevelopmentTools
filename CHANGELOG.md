# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Redaction follows one shared specification instead of a patch per reported bypass. The rule: what
the policy does not fully understand is hidden, never shown. It is built for secrets recorded by
accident; structured input is default-safe and free text is a best effort with one cut point (see
"Threat model" in the redaction guide). Redaction is a safety net, not a guarantee; keep secrets
out of logs in the first place.

### Security

- Keys (JSON member names, form, query and multipart field names, header names) are read after
  their escapes are decoded by the parser. Only a key made of ASCII letters, digits, `_`, `-`, `.`
  and spaces is compared with the secret names, with the separators folded away and the letters
  lowercased. Any other key has its value hidden: a letter outside ASCII (also a full-width one),
  look-alike letters from another script, format characters such as ZWJ or a soft hyphen,
  combining marks, other punctuation, an empty key and a key longer than 256 characters. A key
  that matches hides its whole value, whatever its type, at every repetition.
- Names written as values are read by the same rule: `{"name":"Authorization","value":…}`, JSON
  Patch and SCIM `{"op":…,"path":"/password","value":…}`, `label=Password&value=…`,
  `[["Authorization","…"]]`, and a name that is not plain ASCII or has no letter or digit
  (`Şifre`, `ⓟⓘⓝ`, `🔑`) hide the value beside them (`value`, `data`, `content`, … and any member
  with such a word in its name). A name that names a secret word, has no letter or digit, is
  written in styled letters or is held by `key`, `label`, `param` or another member that only
  pairs use hides every member beside it. A `name`, `id` or `type` written in another script or
  with punctuation is as often a person, a place, a product or a media type, so the rest of such
  a record stays: `{"id":42,"name":"Ayşe Yılmaz","price":12.5}` is stored as it is.
- Bodies are parsed, never scanned by hand: JSON with a JSON parser whose tree must agree with
  `JSONSerialization` (stored as sent, with hidden values replaced, so it stays valid JSON), forms
  with the platform's percent decoding, multipart with a strict RFC 2046 and RFC 7578 parser that
  always omits file parts and file names. A body is omitted with a note such as
  `[body omitted: 512 bytes, application/xml]` when its content type is unknown or missing, when it
  does not parse completely, was cut off or is over `maximumBodySize` (256 KiB by default, at
  most 16 MiB), when JSON is in another encoding than
  its `charset` names, and when a common server parser could split it into fields differently: a
  form with a `;`, a bare `%` or a name spelled two ways, a multipart body with `--boundary` other
  than at a CRLF delimiter, LF-only part headers, or a quoted, repeated or over-long boundary. In
  2.0.0, plain-text, XML and other bodies were stored unchecked.
- Headers keep their values only when they are on an allowlist (by default `Accept`,
  `Accept-Encoding`, `Accept-Language`, `Cache-Control`, `Content-Encoding`, `Content-Length`,
  `Content-Type`, `ETag` and `User-Agent`). `Authorization`, `Proxy-Authorization`, `Cookie`,
  `Set-Cookie`, `X-Api-Key`, names with `token`, `secret`, `key`, `auth`, `session` or `signature`
  and names that are not ASCII tokens stay hidden when listed, and so do values that start with an
  authentication scheme, as in 2.0.0.
- URLs lose their user info and fragment. Query values are hidden unless the parameter is on an
  allowlist, which is empty by default, and a query that servers could split differently is
  written as `?[REDACTED]`. A host that is neither a name of ASCII labels nor an IP address, or in
  which a value detector finds something, is reduced to the scheme. Path segments that look like identifiers or secrets become `:id`, and
  so does the segment after one that names a secret. A path of more than 64 segments or a query of
  more than 128 parameters is recorded with its scheme, host and port only.
- Free text (`LogStore` messages, error descriptions of failed requests, kept header values,
  `text/plain` bodies and the strings of structured input) has one cut point: from the first
  trigger, everything to the end of the text is hidden, the lines below included. The triggers
  are a key before `=` or `:` that is not on `allowedTextKeys` (`status`, `method`, `path`,
  `duration_ms` and `count` by default), also in JSON members, two-element arrays and quoted keys
  in the text; a secret name with or without a separator, quoted or not, also written as a value
  (`name="pin"`); a key that is not plain ASCII, has no letter or digit, or
  is missing; the words of a key that name a secret when read together (`pass word=`); a
  character outside the safe alphabet (letters, marks and digits of any script, the ASCII space,
  tab, LF and CR, printable ASCII), judged by its own Unicode category, so `꞉`, `≔`, `＝`, `…`,
  `‥`, `№`, emoji, VT, FF, U+0085 and U+2028 cut the text; an escape (`%3D`, `&#61;`, `\u0041`,
  `\=`), which is never decoded; a word longer than 256 characters; a word that mixes scripts or
  holds an invisible character; markup, from its first `<` that is not a comparison; a quote that
  does not close on its line; a bracket that does not close; and JSON that does not parse. Text
  with no trigger is kept as it is, apart from the value detectors, and JSON in it is read by the
  key rule of structured input.
- A URL in free text has no island logic. It stays visible only when it is clean:
  `scheme://host` with an optional path of ASCII letters, digits, `.`, `_`, `-` and `/`, a host
  name or IPv4 address, no host or path segment that names a secret, and after it white space, a
  line break, the end of the text or one of `.`, `,`, `!` and `)` followed by one of those. Any
  other URL hides the text from where the URL starts: one with a query, a fragment, `;`, `%`, `=`,
  `:`, `@`, `\`, a port, user info, an escape or a character outside ASCII, and one that a quote,
  `>`, a backtick, `]`, `}` or two marks follow (`GET https://api.example.com/v1/items?page=2 done`
  is stored as `GET [REDACTED]`). `allowedQueryParameters` applies to recorded URLs, not to URLs in
  text. Earlier builds of this release read the query, fragment and path parameters of a URL in
  text and read on after them; reviews got values past that reading through an empty or allowed
  section after a secret segment (`/password# hunter2`), an encoded `=` or `:` at the end
  (`/user%3A hunter2`) and an escape in the path (`/x\u003d hunter2`).
- A `:` between two digits is part of a number only when both sides are a whole number: a
  number before it, and after it the two digits of a time (with seconds, a fraction, `Z` or an
  offset) or, after an IPv4 address, a port of at most five digits, then white space, the end of
  the text or closing punctuation (`12:30`, `12:30:45,123`, `2026-10-19T12:30:00Z`,
  `10.0.0.1:8080`). Any other `:` is a separator, so `curl -u admin1:2345678901` is stored as
  `curl -u admin1:[REDACTED]` and `curl -u 42:2345678901` as `curl -u 42:[REDACTED]`. An earlier
  build of this release looked only at the left side; a review got values through after a number
  used as a key (`42:2345678901`, `12:34hunter2`, `10.0.0.1:8080secretvalue`, `12:30:4f9a2c7b`),
  in a line, a JSON string and an allowed header. A ratio such as `16:9` is now cut as well.
- One letter that has no ASCII form put in before the last letter of a secret word
  (`tokeꞏn`, `piın`, `keıy`, `pꞏw`) is read as no letter as well as the last letter, so the word
  is found where it has to end a name. Before, the match took the first reading only and missed
  14 of 16 short secret words in free text, URL path segments, record names and allowed query
  values.
- Such a letter right after a secret word is read as its plural `s` and as no letter before a
  plural `s`, so `tokenꞏ`, `tokenꞏs`, `keyꞏs` and `/v1/otpł/…` are found like `tokens`. Before,
  the match stopped once the word was spelled whole, and short secret words (`token`, `key`,
  `pin`, `otp`, `card`, …) followed by such a letter were not found in free text, JSON strings,
  form values, text/plain and multipart parts, an allowed header, LogStore lines and URL path
  segments.
- Each word of free text is also read as its ASCII skeleton, as the redaction spec says: every
  letter that has no ASCII form is left out, however many there are and wherever they stand, and
  the rest is compared with the secret names, the plural `s` included. `tokensı`, `keysꞏ`,
  `pinsı`, `otpsł`, `user_tokensı`, `myTokensı`, `tokenꞏꞏ`, `tokenꞏsꞏ` and `pıaıssword` are found
  like `tokens`, `keys`, `pins`, `otps`, `user_tokens`, `myTokens`, `token`, `tokens` and
  `password`. Before, the match read one such letter and none after the plural `s`, so these
  words and the values after them were stored as they were in free text, JSON strings, form
  values, text/plain bodies, an allowed header and URL path segments. A name with two or more of
  its letters replaced by look-alikes (`pɑsswoʀd hunter2`) is still not found, as the guide says.
- Markup in free text is not parsed, as the redaction spec says, and what may follow a `<` is
  listed instead of what makes a tag: a `<` is a comparison only before an ASCII space, a tab, a
  line break, an ASCII digit, `=` or the end of the text. Before anything else it cuts the text,
  so `<status>200</status> hunter2`, `<!-- hunter2 -->`, `<![CDATA[hunter2]]>`, `<?pi hunter2?>`,
  `</x> hunter2`, `<!DOCTYPE html> hunter2`, `<br/> hunter2`, `a <# c`, `1 <> 2` and
  `List<String> items` are cut at the `<`. Before, an allowlist of tags and the text of the
  element that was open decided: an allowed tag kept its text, and comments, CDATA, processing
  instructions, end tags and self-closing tags kept the text after them.
- A quote that does not close on its line cuts the text at the quote, and so does a quoted key
  with a line break in it: `msg "abc` with `hunter2" done` on the next line is stored as
  `msg [REDACTED]`, in a log line, a `text/plain` body and a JSON string alike. Before, a quote
  closed at the next one anywhere in the text, so the lines in between were kept.
- Quotes in free text are read as nested: a quote of one of six kinds (`"`, `'` and a
  backtick, plain or escaped) opens inside a quote of another and closes at the next one of its
  kind on its line only while it is the innermost quote open. Quotes that overlap (`'x "y' z"`,
  `"a \" b"`) cut the text at the earliest quote still open, as a quote still open at a line
  break does. `status='x "y'` with `hunter2" ok` on the next line is stored as
  `status=[REDACTED]`, and so is `status='x "y' "c` with `hunter2" ok`, in a log line, a
  `text/plain` body and a JSON string alike; the same holds for a backtick quote, `"x \"y"`,
  `"x 'y"` and `'"note'` before `Qx31": 1`. Before, one quote was kept open at a time and the
  quotes inside it opened nothing, so the value on the next line showed; and a first fix that
  read each kind of quote on its own took the second `"` of `'x "y' "c` for the close of the
  first, so it showed again. `"a \" b" done` is now stored as `[REDACTED]`.
- A quoted key that is not on `allowedTextKeys` cuts the text at its opening quote, whichever
  quote it is written in: `"x":"hunter2"`, `"x"="hunter2"`, `'x': 'hunter2'` and `"hunter2":"v"`
  are stored as `[REDACTED]`. Before, the cut came after the separator, so the key showed.
- A clean URL in free text may be followed only by white space, a line break, the end of the text
  or one of `.`, `,`, `!` and `)` and then one of those; anything else cuts the text where the URL
  starts. Before, one of `.,!)]}>"'` and a backtick ended a clean URL whatever came after it, so
  `see https://a.example/v1/x), ok`, `x'y ok`, `x>y ok` and `x> ok` kept the URL, and `x"y` cut
  the text at the quote with the URL showing. The last segment of a clean URL is read with the
  next word, as two words are (`https://x.example/to ken hunter2`).
- `NetworkEntry.host` is the host as the recorded URL writes it: `[REDACTED]` when the URL rule
  hides it (`myapp://password=hunter2/x`, a card number or a token in the host). Before, it kept
  the host as the request had it, and the list of requests in the console showed it.
- A backslash before `x`, `u`, `U`, `N`, `o` or an octal digit is an escape in free text whatever
  follows it, so `\x{70}assword`, `\U00000070assword`, `\N{LATIN SMALL LETTER P}assword` and
  `\o{160}assword` cut the text like `\u0070assword` does.
- Multipart part headers keep their names only when they are on the header allowlist; any other
  is written as `[REDACTED]: [REDACTED]`.
- A `LogStore` message is redacted up to 1 MiB of Unicode scalars, on the thread that logs it; a
  longer one is redacted up to its last line break before that length and the rest is hidden.
- Values are scanned for JWTs, bearer credentials, hex or Base64 strings of 32 or more characters,
  card numbers (Luhn), IBANs (mod 97), email addresses with names and domains in any script and the
  password in `user:password@host`, in the same way in bodies, free text, URLs and JSON strings.
- Hostile input is bounded: JSON may be open 64 levels deep across every document a text is in, at
  most four documents are read one inside another, and the documents found in one input read at
  most four times its length. The tests run on a thread with 512 KiB of stack and, in a release
  build, check that a megabyte of input takes less than a second and, on macOS, that a megabyte of
  free text takes less than 16 MB of memory beyond the input.

### Added

- `RedactionPolicy(additionalSecretNames:allowedHeaders:allowedQueryParameters:allowedTextKeys:maximumBodySize:urlDetail:)`,
  `redact(text:)`, `URLDetail` (`.hostOnly` records only scheme, host and port),
  `defaultSecretNames`, `defaultAllowedHeaders`, `defaultAllowedTextKeys`, `headerParameterNames`,
  `secretNames`, `allowedHeaders`, `allowedQueryParameters`, `allowedTextKeys`, `maximumBodySize`,
  `defaultMaximumBodySize`, `bodySizeLimit`, `maximumJSONDepth`, `maximumNestedDocuments`,
  `maximumPathSegments`, `maximumQueryParameters`, `LogStore.Configuration.redaction` and
  `LogStore.maximumRedactedMessageLength`.
- A test for each bypass class of the specification, every bypass reported against earlier
  versions, the test inputs of 2.0.0, property tests with generated obfuscations of every secret
  name, generated triggers after which no value may show and generated keys, tests that ordinary
  keys, allowlisted headers and text with no trigger stay readable, parser-differential, stack,
  time-limit and peak-memory tests, the probes of every review of the shared rules, and the
  examples of the guide. 512 tests run on macOS and 509 on an iOS simulator.

### Changed

- `RedactionOutcome.withheld` is now `.omitted`, and an omitted body stores the note in place of
  its bytes. The console, HAR files and cURL commands say why a body is missing.
- Secret names replace name fragments: a name of five or more letters counts anywhere in a key, a
  shorter one (`key`, `pin`, `otp`) as one of its words or at its end, and `pass`, `pw` and `sid`
  only as a word, so `keyboard` and `bypass` keep their values while `author` no longer matches
  `auth`. `bearer` is one of the names, since what follows it is a credential.
- JSON bodies are stored as sent instead of serialized again, and UTF-16 and UTF-32 JSON is stored
  as UTF-8. A query parameter without `=` is kept only when it is allowlisted.
- The Unicode properties redaction asks of a scalar are looked up once for the Basic Multilingual
  Plane and shared, and JSON and form text is encoded for the platform parsers without building
  a string scalar by scalar. A megabyte of an array of strings quoted in JSON three times took
  0.72 s on a 512 KiB thread in a release build and takes about 0.3 s on the same machine; no
  shape of the time-limit tests takes more than 0.4 s there.

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
