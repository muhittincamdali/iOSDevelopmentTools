# Contributing

Thanks for taking the time to improve iOSDevelopmentTools.

## Reporting bugs

Open an issue with:

- what you did (the request, the log call or the console screen) and what happened,
- the platform and OS version (simulator or device, iOS or macOS) and the Xcode version,
- for a request that is recorded wrongly or not at all: how the session is created (shared,
  your own configuration, a library such as Alamofire) and whether `NetworkCapture.start()` runs
  before the session is created,
- a cURL command or HAR export of the request if it helps (they are already redacted).

A value that should have been redacted but was stored is a security issue: report it privately
as described in [SECURITY.md](SECURITY.md), not in a public issue.

## Pull requests

1. Fork the repository and branch from `master`.
2. Keep each pull request focused on one change.
3. Run the tests on both platforms:

    ```sh
    swift test
    xcodebuild test -scheme iOSDevelopmentTools \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
    ```

4. If you change a README code sample, change the copy in
   `Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift` as well. That file is what gets
   compiled: by the example app, and by `swift test` through the link
   `Tests/iOSDevelopmentToolsTests/ReadmeSamples.swift`. Build the app with:

    ```sh
    cd Examples/DevToolsDemo
    xcodebuild build -scheme DevToolsDemo -destination 'generic/platform=iOS Simulator'
    ```

5. If the console looks different after your change, recapture the README screenshots with
   `scripts/capture-screens.sh` (it needs a network connection; the example app sends real
   requests).
6. `README.md` has translations (`README.<language>.md`). Each one records the version of
   `README.md` it follows, and CI fails while a translation is behind. If you change `README.md`
   and cannot update the translations, say so in the pull request and they will be updated
   before it is merged.

## Where things are

| Folder | Contents |
| --- | --- |
| `Sources/iOSDevelopmentTools/Network` | `NetworkCapture`, the `URLProtocol` that records and forwards requests, `NetworkLogger`, `NetworkEntry` |
| `Sources/iOSDevelopmentTools/Redaction` | `RedactionPolicy`: names, URLs and headers in `+Apply`, bodies in `+Body` |
| `Sources/iOSDevelopmentTools/Export` | cURL commands and HAR files |
| `Sources/iOSDevelopmentTools/Logging` | `LogStore`, `LogEntry`, `LogFilter` |
| `Sources/iOSDevelopmentTools/Diagnostics` | `DeviceSnapshot` |
| `Sources/iOSDevelopmentTools/Console` | The SwiftUI console |
| `Tests/iOSDevelopmentToolsTests/Support` | `StubServer`, which answers forwarded requests in the capture tests |

## Rules the code keeps

- **Nothing unredacted is stored.** Every value goes through `RedactionPolicy` before a
  `NetworkEntry` is created. A redaction change needs a test with the bypass it closes.
- **Memory has an upper bound.** Stores are ring buffers, limits are clamped, request bodies over
  4 MiB are streamed. New buffers need a limit and a test at the limit.
- **Conversions cannot trap.** A `Double` is checked for NaN, infinity and range before it is
  converted to an integer, a `Duration` or JSON, with a test for each.
- **The app sees the network unchanged.** Capture tests check what the stub server received and
  what the app received, not only what was stored.
- The HAR creator version is `HTTPArchive.creatorVersion`; update it with each release.

## Code style

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- The package builds in the Swift 6 language mode with strict concurrency; new code should not
  add warnings.
- Document public API with DocC comments (`///`).
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `ci:`, `chore:`).

## License

By contributing you agree that your contributions are licensed under the MIT License.
