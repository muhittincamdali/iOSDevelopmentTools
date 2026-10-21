<!-- i18n-source: README.md@46cdddcee504e0c7ba46c8a005fb8ad9dd742676 status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-zh-CN-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-zh-CN-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-zh-CN-light.svg" alt="iOSDevelopmentTools: 在应用内控制台中查看应用的网络请求、日志和设备状态，敏感信息会被遮盖。"></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="CI 状态"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="最新版本: v2.0.0"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="支持的平台: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="语言版本: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="许可证: MIT"></picture></a>
</p>

<p align="center">
<a href="#快速开始"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-zh-CN-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-zh-CN-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-zh-CN-light.svg" alt="开始使用"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-zh-CN-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-zh-CN-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-zh-CN-light.svg" alt="文档"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-zh-CN-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-zh-CN-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-zh-CN-light.svg" alt="示例"></picture></a>
</p>

> 本文是英文 README 的译文。如两者内容不一致，以英文版为准。

<!-- brand:end -->

一个 Swift 包，把调试控制台放进你的 iOS 或 macOS 应用。它会记录应用通过 `URLSession` 发出的请求，
保存你的日志消息，并收集设备报告，然后把这三类内容显示在 SwiftUI 控制台中；控制台可以通过摇一摇、
按钮或独立窗口打开。打开某个请求即可查看它的请求头、消息体和耗时，也可以把它作为 cURL 命令分享，
或导出为 HAR 文件，供浏览器开发者工具、Charles 或 Proxyman 使用。密码、令牌、Cookie 和 API 密钥在
存储之前就会被替换，因此不会出现在控制台、导出的文件或错误报告的截图里。它面向调试和测试构建，
没有任何依赖，并按照 Swift 6 strict concurrency 编写。

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="Network 标签页列出了示例应用的七个真实请求：一个发往未知主机的失败请求、一个 503、一个 404，以及四个成功的请求，并显示各自的耗时和大小"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="在控制台中打开的一个登录请求：Authorization 请求头和 JSON 消息体中的密码都显示为 [REDACTED]"></picture>
</p>

## 亮点

- **一行代码开始记录** — `NetworkCapture.start()` 会记录 `URLSession.shared`，以及之后用默认或
  ephemeral 配置创建的每个会话，包括基于 `URLSession` 构建的库。你的应用收到的每个响应都保持原样。
- **存储前先脱敏** — 秘密名称（`password`、`token`、`api_key`，无论怎么拼写或转义）下的值，以及
  不是纯 ASCII 的键下的值都会被替换，只有允许列表中的请求头和查询参数会保留值。JSON、表单和
  multipart 消息体会被解析；无法解析的消息体不会被存储，而是替换为一条说明。日志消息中从第一个
  秘密名称或不在允许列表中的键到结尾的内容都会被隐藏。
- **存储有上限** — 默认最多保留 500 个请求，每个消息体最多 256 KiB；日志消息保存在环形缓冲区中，
  超过 4 MiB 的上传以流的方式处理，而不是复制。头部和 URL 会完整保存，不会截断。
- **导出** — 任何请求都可以导出为可安全用于 shell 的 `curl` 命令，任何请求列表都可以导出为
  HTTP Archive (HAR 1.2)。
- **日志和设备报告** — `LogStore` 保存带级别和类别的消息，同时把它们写入统一日志系统
   (unified logging)；`DeviceSnapshot` 报告版本、操作系统、型号、内存占用、散热状态，以及是否
  附加了调试器。
- **经过测试** — macOS 上有 560 个 Swift Testing 测试，iOS 模拟器上有 557 个。请求从应用的会话
  经过捕获层到达一个 stub 服务器，测试会检查服务器收到了什么、应用收到了什么，以及存储了什么。

## 快速开始

**1. 添加软件包**

在 Xcode 中选择 **File › Add Package Dependencies…**，然后输入仓库地址：

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

把它粘贴到窗口右上角的搜索框中。将 **Dependency Rule** 保持为从 `2.0.0` 开始的
**Up to Next Major Version**，然后点击 **Add Package**。在下一个窗口中，在 **iOSDevelopmentTools**
旁边选择你的应用 target，再次点击 **Add Package**。

**2. 导入模块**

```swift
import iOSDevelopmentTools
```

把这一行放在声明 `App` 的文件顶部，位于 `import SwiftUI` 之下。

**3. 开始记录并添加控制台**

在应用的 `App` 文件中，于 `init` 里启动捕获，并把控制台添加到根视图。`#if DEBUG` 这几行可以让两者
都不进入 release 构建：

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

在 iPhone 模拟器上运行应用，让它发出一个请求，然后在 Simulator 菜单中选择 **Device › Shake**。
控制台会打开到 Network 标签页，列表中可以看到这个请求。

`devToolsConsoleOnShake()` 仅在 iOS 上可用。如果你的应用也为 macOS 构建，请改用 `#if DEBUG && os(iOS)`
包裹它，并按照下文 **在 macOS 上使用** 中的方式为控制台提供一个窗口。

## 安装

### Swift Package Manager

在 Xcode 中选择 **File › Add Package Dependencies…**，然后输入仓库地址：

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

或者将其添加到 `Package.swift` 的 `dependencies` 中：

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

## 使用方法

下面的示例复制自
[ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift)，示例应用和测试套件
都会编译这个文件。

### 通过按钮打开控制台

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### 记录你自己创建的会话

在 `NetworkCapture.start()` 之后用 `.default` 或 `.ephemeral` 创建的会话会被自动记录。对于更早
创建的会话，请把记录功能添加到它的配置中：

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### 选择保留的内容

超出范围的限制值会被限定到范围内。秘密名称与所比较的键以相同方式规范化，因此
`"license_number"` 也能匹配 `licenseNumber` 和 `LICENSE-NUMBER`，并且只有列出的查询参数会保留值：

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

### 记录哪些内容

- **会记录：** 方法、状态码、耗时、请求头名称、允许列表中请求头的值（默认是 `Accept`、
  `Accept-Encoding`、`Accept-Language`、`Cache-Control`、`Content-Encoding`、`Content-Length`、
  `Content-Type`、`ETag` 和 `User-Agent`）、URL 的协议、主机、路径和查询参数名称，以及脱敏后的
  JSON、表单、multipart 和 `text/plain` 消息体。
- **绝不记录：** URL 中的用户信息和片段、不在允许列表中的查询值、其他所有请求头的值（`Authorization`、
  `Cookie` 和 `Set-Cookie` 即使在允许列表中也不记录）、`password`、`token`、`api_key` 等秘密名称下的
  值、看起来像标识符的路径段（显示为 `:id`），以及 multipart 消息体中的文件部分。
- **不是纯 ASCII 的键**（在解码转义、应用 NFKC 并统一大小写之后，例如含西里尔字母 `а` 的
  `pаssword`、`pass\u200Dword`、`şifre`）的值默认会被隐藏。
- **无法解析的消息体**（未知或缺失的内容类型、格式错误的 JSON 或 multipart、在大小上限处被截断的
  消息体）会被替换为 `[body omitted: 512 bytes, application/xml]` 这样的说明。
- **日志消息**只保留到第一个触发点之前：秘密名称、不在允许列表中的键（默认是 `status`、`method`、
  `path`、`duration_ms` 和 `count`，可用 `allowedTextKeys` 添加自己的键）、ASCII 之外且不是字母、
  附加符号、数字或空白的字符（`꞉`、`…`、表情符号）、`%3D` 这样的转义序列、不被允许的带引号的键
  （从开引号处截断：`"x":"hunter2"` 会存储为 `[REDACTED]`）、标记（不是比较的 `<`：`<b>`、`</x>`、
  `<!--`；任何标签都不保留其文本）、在本行内未闭合的引号、相互交叠的引号（`'x "y' z"`）或未闭合的括号，会让其后的所有内容（包括
  下面的行）都被隐藏（`login password=hunter2 status=200` 会存储为
  `login password=[REDACTED]`，`x=hunter2` 会存储为 `x=[REDACTED]`）。没有触发点的消息会原样保留，
  只有检测到的令牌、卡号和电子邮件地址会被隐藏。
- **日志消息中的 URL** 没有孤岛逻辑。URL 只有在干净时才会保留原样：形式为 `scheme://host`，
  可选路径只含 ASCII 字母、数字、`.`、`_`、`-` 和 `/`，主机和路径段都不是秘密名称，并且其后
  紧跟空格、行尾、文本结尾，或 `.`、`,`、`!`、`)` 中的一个再接上述之一。其他任何 URL（带查询、片段、
  端口、用户信息或 `%3D` 这类转义，或其后跟引号或两个标点）
  都会让消息从 URL 开始处起被隐藏（`GET https://api.example.com/v1/items?page=2 done` 会存储为
  `GET [REDACTED]`）；`allowedQueryParameters` 只用于记录下来的请求 URL，不用于文本中的 URL。

脱敏只是一道安全网，而不是保证。它针对的是意外记录下来的秘密：结构化输入会用解析器读取，
解析器不能完全理解的内容都会被隐藏；自由文本只能尽力而为，不带 `=` 或 `:`、且有两个或更多
字母被替换为相似字母的秘密名称（`pɑsswoʀd hunter2`）不保证能被发现。从一开始就不要让秘密进入
你记录的请求和日志消息，并优先使用结构化日志。

这个模型还包括两个限制。**开销上限：** 一个输入中嵌套的所有文档（字符串中的 JSON、文本中的
URL）合计最多读取输入长度的四倍；超出这个预算后，包含下一个文档的字符串会被整体隐藏。**多行布局**
不需要特殊处理：单独一行的 property list `<key>`、分布在多行的 JSON 和以文本形式写出的 multipart
消息体都会从第一个触发点隐藏到文本末尾，所以无论值写在哪里都会被隐藏。

### 记录日志消息

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### 导出请求和报告

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

控制台的分享菜单会为用户完成同样的事情：Network 标签页中的 **Export HAR**、请求详情中的
**Share as cURL**，以及 Device 标签页中的 **Share Report**。

### 在 macOS 上使用

Mac 应用没有摇一摇。给控制台一个独立的窗口，并用快捷键打开它：

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

## 演示

<table>
<tr>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="Logs 标签页显示示例应用的 info、warning 和 error 消息，每条都带有类别、时间和源代码行"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="Device 标签页显示应用版本、iOS 版本、模拟的设备型号、内存、应用内存、散热状态、Low Power Mode 和调试器状态"></picture></td>
</tr>
</table>

截图来自[示例应用](Examples)，运行在 iOS 27 的 iPhone 17 Pro 模拟器上，由
[`scripts/capture-screens.sh`](scripts/capture-screens.sh) 截取。请求都是真实的：应用把它们发送到
`api.github.com` 和 `postman-echo.com`。要运行它，请打开
`Examples/DevToolsDemo/DevToolsDemo.xcodeproj`，选择一个 iPhone 模拟器或 **My Mac**，运行，然后
点击 **Send All**。

## 文档

API 参考文档与文章：

- [API 参考](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — 每个公开类型及其参数和限制。

## 指南

- [入门](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — 添加包、启动捕获、打开控制台、记录日志消息。
- [捕获网络流量](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — 哪些会话会被记录、请求如何到达服务器、内存限制，以及哪些内容不会被记录。
- [对敏感数据脱敏](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — 哪些内容会记录、哪些绝不记录，键如何匹配，为什么有些消息体会被省略，以及相关限制。
- [让这些工具不进入 release 构建](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — 编译条件和一个单独的内部 target。

## 系统要求

| 平台 | 最低版本 |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| 工具链 | Swift 6.2 · Xcode 26+ |

摇一摇手势仅适用于 iOS；在 macOS 上，控制台会在窗口或 sheet 中打开。

## 架构

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture` 为 `URLSession.shared` 注册 `CaptureProtocol`（一个 `URLProtocol`），并把它添加到
  默认和 ephemeral 配置中。该协议通过一个内部的 `URLSession` 转发每个请求，并在发起加载的线程上回调
  应用的会话。
- `RedactionPolicy` 在创建 `NetworkEntry` 之前运行，因此存储和导出看到的始终只是脱敏后的值。
- `NetworkLogger` 和 `LogStore` 是带锁保护的环形缓冲区，通过 `AsyncStream` 发布变更；控制台的
  observable 模型每秒最多读取它们大约七次。
- 控制台视图之外的所有内容都是 `Sendable`，可以在任何线程上调用。

## 路线图

计划中的内容，不分先后：跨启动保留请求、为 `LogStore` 提供 `swift-log` 后端、控制台对 tvOS 和
visionOS 的支持，以及请求 mock。欢迎在
[issue](https://github.com/muhittincamdali/iOSDevelopmentTools/issues) 中提出建议。

## 参与贡献

欢迎参与贡献。提交 pull request 之前，请先阅读[贡献指南](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md)和[行为准则](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md)。如发现安全问题，请按照[安全策略](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md)私下报告。

## 许可证

基于 MIT 许可证发布。详见 [LICENSE](LICENSE)。
