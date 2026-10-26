# Getting started

Add the package, start recording, and open the console in a few minutes.

## Overview

This article sets up iOSDevelopmentTools in a new SwiftUI app for iOS. The same steps work on
macOS, where the console opens from a window instead of a shake (see the last section).

### Add the package

In Xcode, choose **File › Add Package Dependencies…**, enter
`https://github.com/muhittincamdali/iOSDevelopmentTools.git`, leave the rule at **Up to Next
Major Version** from `2.1.1`, and add the **iOSDevelopmentTools** library to your app target.

### Start recording and add the console

Call ``NetworkCapture/start(logger:)`` as early as possible, before the app creates its
`URLSession` instances, and add ``SwiftUICore/View/devToolsConsoleOnShake(networkLogger:logStore:)``
to the root view:

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

Run the app, make a request, and shake the device (in the simulator: **Device › Shake**). The
Network tab lists the request; tap it to see its headers, body and timings.

### Log messages

Log with ``LogStore`` instead of `print`. Messages appear in the Logs tab and in Console.app,
after redaction: from the first secret name in a message, a key that is not on the allowlist
(`status`, `method`, `path`, `duration_ms` and `count` by default) or anything else that cannot be
read with certainty, the rest of the message is hidden (see <doc:RedactingSensitiveData>):

```swift
LogStore.shared.info("Signed in", category: "auth")
LogStore.shared.error("Payment failed: \(error.localizedDescription)", category: "checkout")
```

### Open the console from a button

A shake is not always convenient. Present the console from your own debug menu with
``SwiftUICore/View/devToolsConsole(isPresented:networkLogger:logStore:)``:

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### Use it on macOS

On macOS, give the console a window of its own and open it with a keyboard shortcut:

```swift
Window("Developer Tools", id: "devtools") {
    DevToolsConsole()
}
.keyboardShortcut("d", modifiers: [.command, .option])
```

## See Also

- <doc:CapturingNetworkTraffic>
- <doc:KeepingToolsOutOfReleaseBuilds>
