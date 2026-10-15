# Keeping the tools out of release builds

Make sure the console and request recording only exist in the builds you test with.

## Overview

The console shows every request the app makes. Redaction removes the secrets it knows about, but
the console is still a debugging tool: ship it to testers, not to the App Store.

### Wrap the calls in a compilation condition

Wrap every call in `#if DEBUG`, or in a condition of your own for test builds such as
`INTERNAL`, set under **Build Settings › Active Compilation Conditions** of the configurations
you hand to testers:

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

When no call is compiled in, nothing starts: ``NetworkCapture`` does nothing until
``NetworkCapture/start(logger:)`` runs, the shake handler is added only when
``SwiftUICore/View/devToolsConsoleOnShake(networkLogger:logStore:)`` appears, and ``LogStore`` only
holds what you log.

### Leave the package out of release builds

To keep the package's code out of the release binary entirely, link it only in the
configurations that use it. In Xcode, the simplest way is a second app target (for example
`MyApp Internal`) that links iOSDevelopmentTools and sets the `INTERNAL` condition; the App Store
target does not link the package at all.

### Log messages in release builds

``LogStore`` is useful in any build, and it writes to the unified logging system with private
visibility, as `os.Logger` does by default. To keep messages only in the system log in release
builds, set ``LogStore/Configuration/maximumEntries`` low or log through `os.Logger` directly
there.

## See Also

- <doc:GettingStarted>
