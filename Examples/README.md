# Examples

## DevToolsDemo

A SwiftUI app for iOS 17+ and macOS 14+ that sends seven requests to public services and shows
them in the console: JSON and text responses, a sign-in request whose password and bearer token
are redacted, an API key in a query string, a 404, a 503 and a host that does not exist.

It uses the package from this repository (`path: ../..`), so it always builds against the current
sources. CI builds it for iOS and macOS on every push.

### Run it

1. Open `DevToolsDemo/DevToolsDemo.xcodeproj` in Xcode 26 or later.
2. Choose the **DevToolsDemo** scheme and an iPhone simulator or **My Mac**.
3. Press **Run**, tap **Send All**, then **Open Developer Tools** (on iOS you can also shake the
   device: **Device › Shake** in the simulator; on macOS press ⌥⌘D).

The requests need a network connection. Without one, every request shows up as failed, which is
also something the console can show.

### Files

| File                                                                     | What it shows                                                                                           |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| [DevToolsDemoApp.swift](DevToolsDemo/DevToolsDemo/DevToolsDemoApp.swift) | `NetworkCapture.start()` at launch, and a `Window` scene for the console on macOS                       |
| [DemoView.swift](DevToolsDemo/DevToolsDemo/DemoView.swift)               | The sample requests, a button that opens the console, `devToolsConsoleOnShake()` and `NetworkEntryView` |
| [ReadmeSamples.swift](DevToolsDemo/DevToolsDemo/ReadmeSamples.swift)     | Every code sample in the README. `swift test` compiles and runs them too, through a link in `Tests/`    |

### Launch arguments

[`scripts/capture-screens.sh`](../scripts/capture-screens.sh) uses these to open a screen
without tapping:

| Argument                                               | Effect                                                            |
| ------------------------------------------------------ | ----------------------------------------------------------------- |
| `-run-requests`                                        | Sends all sample requests at launch                               |
| `-console network`, `-console logs`, `-console device` | With `-run-requests`, opens the console on that tab afterwards    |
| `-entry "Sign in"`                                     | With `-run-requests`, opens that request's detail view afterwards |

### Regenerate the project

The Xcode project is generated from [`project.yml`](DevToolsDemo/project.yml) with
[XcodeGen](https://github.com/yonaskolb/XcodeGen). After changing `project.yml`, run `xcodegen`
in `Examples/DevToolsDemo`.
