<!-- i18n-source: README.md@ac7067d8ac5e8db13f709ed3f630d0abc25ebc2f status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ja-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ja-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ja-light.svg" alt="iOSDevelopmentTools: アプリのネットワークリクエスト、ログ、デバイスの状態をアプリ内コンソールで確認。機密情報は伏せ字になります。"></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="CI ステータス"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="最新バージョン: v2.0.0"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="対応プラットフォーム: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="言語バージョン: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="ライセンス: MIT"></picture></a>
</p>

<p align="center">
<a href="#クイックスタート"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ja-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ja-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ja-light.svg" alt="はじめる"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ja-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ja-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ja-light.svg" alt="ドキュメント"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ja-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ja-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ja-light.svg" alt="サンプル"></picture></a>
</p>

> このドキュメントは英語版 README の翻訳です。内容が異なる場合は英語版が最新です。

<!-- brand:end -->

iOS または macOS アプリの中にデバッグ用コンソールを組み込む Swift パッケージです。アプリが
`URLSession` で送信するリクエストを記録し、ログメッセージを保持し、デバイスレポートを収集して、
この 3 つをすべて SwiftUI のコンソールに表示します。コンソールはシェイク、ボタン、またはウィンドウで
開けます。リクエストを開くとヘッダー、ボディ、所要時間を確認でき、cURL コマンドとして、またはブラウザーの
開発者ツール、Charles、Proxyman 向けの HAR ファイルとして共有することもできます。パスワード、トークン、
Cookie、API キーは保存される前に置き換えられるため、コンソールにも、書き出したファイルにも、バグ報告の
スクリーンショットにも残りません。デバッグ用・テスト用のビルドでの利用を想定しており、依存関係はなく、
Swift 6 の strict concurrency に対応して書かれています。

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="サンプルアプリの実際のリクエスト 7 件を一覧表示した Network タブ。不明なホストへの失敗したリクエスト、503、404、そして所要時間とサイズ付きの成功したリクエスト 4 件"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="コンソールで開いたサインインのリクエスト。Authorization ヘッダーと JSON ボディ内のパスワードが [REDACTED] と表示されている"></picture>
</p>

## 主な特長

- **1 行で記録開始** — `NetworkCapture.start()` は `URLSession.shared` と、その後に default または
  ephemeral の構成から作られるすべてのセッションを記録します。`URLSession` を基盤にしたライブラリも
  対象です。アプリはすべてのレスポンスを変更されないまま受け取ります。
- **保存前にマスキング** — 機密性の高い名前を持つヘッダー、クエリ、フォーム、multipart、JSON の値は、
  名前の綴りにかかわらず (`X-API-Key`、`api_key`、`API%5FKEY`) 置き換えられます。たとえば途中で切れた
  ためなど、検査できない JSON ボディは、未検査のまま保存されるのではなく保留されます。
- **メモリ使用量は一定** — デフォルトでは最大 500 件のリクエスト、各ボディは 256 KiB までです。
  ログメッセージはリングバッファに保持され、4 MiB を超えるアップロードはコピーせずにストリーミング
  されます。
- **エクスポート** — あらゆるリクエストをシェルで安全に使える `curl` コマンドとして、あらゆる
  リクエストの一覧を HTTP Archive (HAR 1.2) として書き出せます。
- **ログとデバイスレポート** — `LogStore` はレベルとカテゴリ付きのメッセージを保持し、統合ログ
  システム (unified logging) にも書き込みます。`DeviceSnapshot` はバージョン、OS、モデル、メモリ
  使用量、サーマルステート、デバッガーが接続されているかどうかを報告します。
- **テスト済み** — macOS で 115 件、iOS シミュレーターで 116 件の Swift Testing テストがあります。
  リクエストはアプリのセッションからキャプチャ層を通ってスタブサーバーに届き、テストではサーバーが
  受け取ったもの、アプリが受け取ったもの、保存されたものを検証します。

## クイックスタート

**1. パッケージを追加する**

Xcode で **File › Add Package Dependencies…** を選び、リポジトリの URL を入力します。

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

ウィンドウ右上の検索フィールドに貼り付けます。**Dependency Rule** は `2.0.0` からの
**Up to Next Major Version** のままにして、**Add Package** をクリックします。次のウィンドウで
**iOSDevelopmentTools** の横にあるアプリのターゲットを選び、もう一度 **Add Package** をクリックします。

**2. モジュールをインポートする**

```swift
import iOSDevelopmentTools
```

この行は、`App` を宣言しているファイルの先頭、`import SwiftUI` の下に置きます。

**3. 記録を開始してコンソールを追加する**

アプリの `App` ファイルで、`init` 内でキャプチャを開始し、ルートビューにコンソールを追加します。
`#if DEBUG` の行によって、どちらもリリースビルドには含まれません。

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

iPhone シミュレーターでアプリを実行してリクエストを 1 つ送らせ、Simulator メニューの
**Device › Shake** を選びます。コンソールが Network タブで開き、リストにそのリクエストが表示されます。

`devToolsConsoleOnShake()` は iOS 専用です。macOS 向けにもビルドするアプリでは、代わりに
`#if DEBUG && os(iOS)` で囲み、後述の **macOS で使う** のようにコンソール用のウインドウを用意してください。

## インストール

### Swift Package Manager

Xcode で **File › Add Package Dependencies…** を選び、リポジトリの URL を入力します。

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

または `Package.swift` の `dependencies` に追加します。

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

## 使い方

以下のサンプルは
[ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift) からコピーしたもので、
このファイルはサンプルアプリとテストスイートの両方でコンパイルされます。

### ボタンからコンソールを開く

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### 自分で作成したセッションを記録する

`NetworkCapture.start()` の後に `.default` または `.ephemeral` から作成したセッションは、自動的に記録
されます。それより前に作成したセッションには、構成に記録機能を追加します。

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### 保持する内容を選ぶ

範囲外の上限値は範囲内に丸められます。名前の断片は正規化した名前と照合されるため、`"iban"` は
`IBAN`、`iban_number`、`ibanNumber` にも一致します。

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

### メッセージをログに記録する

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### リクエストとレポートをエクスポートする

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

コンソールの共有メニューは、ユーザー向けに同じことを行います。Network タブの **Export HAR**、
リクエスト画面の **Share as cURL**、Device タブの **Share Report** です。

### macOS で使う

Mac アプリにはシェイクがありません。コンソール専用のウィンドウを用意し、ショートカットで開きます。

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

## デモ

<table>
<tr>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="サンプルアプリの info、warning、error のメッセージを、カテゴリ、時刻、ソースの行番号とともに表示した Logs タブ"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="アプリのバージョン、iOS のバージョン、シミュレートされたモデル、メモリ、アプリのメモリ、サーマルステート、Low Power Mode、デバッガーの状態を表示した Device タブ"></picture></td>
</tr>
</table>

スクリーンショットは、iOS 27 の iPhone 17 Pro シミュレーターで[サンプルアプリ](Examples)を実行し、
[`scripts/capture-screens.sh`](scripts/capture-screens.sh) で撮影したものです。リクエストは実際のもの
で、アプリが `api.github.com` と `postman-echo.com` に送信します。実行するには
`Examples/DevToolsDemo/DevToolsDemo.xcodeproj` を開き、iPhone シミュレーターまたは **My Mac** を選んで
実行し、**Send All** をタップします。

## ドキュメント

API リファレンスと解説記事：

- [API リファレンス](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — すべての公開型を、パラメーターと制限とともに掲載しています。

## ガイド

- [はじめに](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — パッケージの追加、キャプチャの開始、コンソールの表示、メッセージのログ記録。
- [ネットワーク通信のキャプチャ](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — 記録されるセッション、リクエストがサーバーに届く仕組み、メモリの上限、記録されないもの。
- [機密データのマスキング](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — 名前の照合方法、置き換えられるもの、一部のボディが保留される理由、そして制限。
- [ツールをリリースビルドに含めない](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — コンパイル条件と、独立した内部用ターゲット。

## 動作要件

| プラットフォーム | 最小バージョン |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| ツールチェーン | Swift 6.2 · Xcode 26+ |

シェイクジェスチャーは iOS のみです。macOS では、コンソールはウィンドウまたはシートで開きます。

## アーキテクチャ

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture` は、`URLProtocol` である `CaptureProtocol` を `URLSession.shared` に登録し、
  default と ephemeral の構成にも追加します。このプロトコルは各リクエストを内部の `URLSession` 1 つを
  通して送り出し、ロードを開始したスレッドでアプリのセッションにコールバックします。
- `RedactionPolicy` は `NetworkEntry` が作成される前に実行されるため、ストアとエクスポートには
  マスキング済みの値しか渡りません。
- `NetworkLogger` と `LogStore` は、ロックで保護されたリングバッファで、変更を `AsyncStream` で発行
  します。コンソールの observable モデルがこれらを読むのは、多くても 1 秒に 7 回程度です。
- コンソールのビュー以外はすべて `Sendable` で、どのスレッドからでも呼び出せます。

## ロードマップ

予定している項目です（順不同）：起動をまたいだリクエストの保持、`LogStore` 用の `swift-log` バックエンド、
コンソールの tvOS と visionOS 対応、リクエストのモック。ご提案は
[issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues) でお待ちしています。

## コントリビューション

コントリビューションを歓迎します。pull request を作成する前に[コントリビューションガイド](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md)と[行動規範](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md)をお読みください。セキュリティ上の問題は[セキュリティポリシー](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md)に従って非公開で報告してください。

## ライセンス

MIT ライセンスで公開しています。詳細は [LICENSE](LICENSE) を参照してください。
