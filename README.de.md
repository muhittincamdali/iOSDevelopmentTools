<!-- i18n-source: README.md@47242880e3cb8d9dd7c78c96d16b195d71e1d385 status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-de-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-de-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-de-light.svg" alt="iOSDevelopmentTools: Netzwerkanfragen, Logs und Gerätestatus deiner App in einer In-App-Konsole prüfen – Geheimnisse werden geschwärzt."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="CI-Status"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="Aktuelle Version: v2.0.0"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="Unterstützte Plattformen: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="Sprachversion: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="Lizenz: MIT"></picture></a>
</p>

<p align="center">
<a href="#schnellstart"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-de-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-de-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-de-light.svg" alt="Loslegen"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-de-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-de-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-de-light.svg" alt="Dokumentation"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-de-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-de-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-de-light.svg" alt="Beispiele"></picture></a>
</p>

> Dies ist eine Übersetzung der englischen README. Bei Abweichungen gilt die englische Fassung.

<!-- brand:end -->

Ein Swift-Paket, das eine Debugging-Konsole in deine iOS- oder macOS-App einbaut. Es zeichnet die
Anfragen auf, die deine App mit `URLSession` sendet, speichert deine Log-Meldungen und erstellt einen
Geräte-Report. Alle drei zeigt es in einer SwiftUI-Konsole, die sich per Schütteln, über einen Button
oder in einem eigenen Fenster öffnen lässt. Öffne eine Anfrage, um ihre Header, Bodys und Laufzeiten zu
sehen, oder teile sie als cURL-Befehl oder als HAR-Datei für die Entwicklerwerkzeuge des Browsers,
Charles oder Proxyman. Passwörter, Tokens, Cookies und API-Schlüssel werden ersetzt, bevor irgendetwas
gespeichert wird; sie landen also weder in der Konsole noch in einer exportierten Datei oder in einem
Screenshot im Fehlerbericht. Das Paket ist für Debug- und Testbuilds gedacht, hat keine Abhängigkeiten
und ist für Swift 6 Strict Concurrency geschrieben.

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="Der Network-Tab mit sieben echten Anfragen aus der Beispiel-App: eine fehlgeschlagene Anfrage an einen unbekannten Host, ein 503, ein 404 und vier erfolgreiche Anfragen mit Dauer und Größe"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="Eine in der Konsole geöffnete Anmeldeanfrage: Der Authorization-Header und das Passwort im JSON-Body zeigen [REDACTED]"></picture>
</p>

## Highlights

- **Eine Zeile zum Aufzeichnen** — `NetworkCapture.start()` zeichnet `URLSession.shared` auf und
  danach jede Session, die aus der default- oder ephemeral-Konfiguration erstellt wird, auch von
  Bibliotheken, die auf `URLSession` aufbauen. Deine App erhält jede Antwort unverändert.
- **Schwärzen vor dem Speichern** — Werte unter geheimen Namen (`password`, `token`, `api_key`,
  egal wie geschrieben oder kodiert) und unter Schlüsseln, die kein reines ASCII sind, werden
  ersetzt; nur Header und Query-Parameter auf der Allowlist behalten ihre Werte. JSON-, Formular-
  und Multipart-Bodys werden geparst; ein Body, der sich nicht parsen lässt, wird durch einen
  Hinweis ersetzt, statt gespeichert zu werden. In einer Log-Meldung wird alles ab dem ersten
  geheimen Namen oder Schlüssel, der nicht auf der Allowlist steht, bis zu ihrem Ende geschwärzt.
- **Begrenzte Speicherung** — standardmäßig höchstens 500 Anfragen und 256 KiB pro Body; Log-Meldungen
  liegen in einem Ringpuffer, und Uploads über 4 MiB werden gestreamt statt kopiert.
  Header und URLs werden vollständig gespeichert.
- **Export** — jede Anfrage als shell-sicherer `curl`-Befehl, jede Liste von Anfragen als HTTP Archive
  (HAR 1.2).
- **Logs und Geräte-Report** — `LogStore` speichert Meldungen mit Level und Kategorie und schreibt sie
  zusätzlich in das Unified Logging System; `DeviceSnapshot` meldet Version, Betriebssystem, Modell,
  Speicherbedarf, thermischen Zustand und ob ein Debugger angehängt ist.
- **Getestet** — 522 Swift-Testing-Tests auf macOS und 519 auf einem iOS-Simulator. Anfragen laufen von
  einer App-Session über die Aufzeichnung zu einem Stub-Server, und die Tests prüfen, was der Server
  erhalten hat, was die App erhalten hat und was gespeichert wurde.

## Schnellstart

**1. Paket hinzufügen**

Wähle in Xcode **File › Add Package Dependencies…** und gib die Repository-URL ein:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Füge sie in das Suchfeld oben rechts im Fenster ein. Lass **Dependency Rule** auf
**Up to Next Major Version** ab `2.0.0` stehen und klicke auf **Add Package**. Wähle im nächsten Fenster
neben **iOSDevelopmentTools** das Target deiner App aus und klicke erneut auf **Add Package**.

**2. Modul importieren**

```swift
import iOSDevelopmentTools
```

Setze diese Zeile an den Anfang der Datei, die deine `App` deklariert, unter `import SwiftUI`.

**3. Aufzeichnung starten und die Konsole hinzufügen**

Starte in der `App`-Datei deiner App die Aufzeichnung in `init` und füge die Konsole zur Root-View
hinzu. Die `#if DEBUG`-Zeilen halten beides aus Release-Builds heraus:

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

Starte die App in einem iPhone-Simulator, lass sie eine Anfrage senden und wähle im Simulator-Menü
**Device › Shake**. Die Konsole öffnet sich im Network-Tab, die Anfrage steht in der Liste.

`devToolsConsoleOnShake()` gibt es nur unter iOS. Wenn deine App auch für macOS gebaut wird,
schließe es stattdessen in `#if DEBUG && os(iOS)` ein und gib der Konsole ein eigenes Fenster, wie
unten unter **Auf macOS verwenden** gezeigt.

## Installation

### Swift Package Manager

Wähle in Xcode **File › Add Package Dependencies…** und gib die Repository-URL ein:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Oder füge es zu den `dependencies` in deiner `Package.swift` hinzu:

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

## Verwendung

Die folgenden Beispiele sind aus
[ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift) kopiert, das die
Beispiel-App und die Test-Suite kompilieren.

### Die Konsole über einen Button öffnen

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### Eine selbst erstellte Session aufzeichnen

Sessions, die nach `NetworkCapture.start()` aus `.default` oder `.ephemeral` erstellt werden, werden
automatisch aufgezeichnet. Für eine früher erstellte Session fügst du die Aufzeichnung ihrer
Konfiguration hinzu:

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### Festlegen, was gespeichert wird

Grenzwerte außerhalb ihres Bereichs werden auf den Bereich begrenzt. Geheime Namen werden wie die
Schlüssel normalisiert, mit denen sie verglichen werden, daher erfasst `"license_number"` auch
`licenseNumber` und `LICENSE-NUMBER`, und nur die aufgeführten Query-Parameter behalten ihre Werte:

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

### Was gespeichert wird

- **Gespeichert:** Methode, Status, Zeiten, Header-Namen, die Werte der Header auf der Allowlist
  (standardmäßig `Accept`, `Accept-Encoding`, `Accept-Language`, `Cache-Control`,
  `Content-Encoding`, `Content-Length`, `Content-Type`, `ETag` und `User-Agent`), Schema, Host,
  Pfad und Query-Parameternamen der URL sowie JSON-, Formular-, Multipart- und `text/plain`-Bodys
  nach dem Schwärzen.
- **Nie gespeichert:** User-Info und Fragment der URL, Query-Werte, die nicht auf der Allowlist
  stehen, die Werte aller anderen Header (`Authorization`, `Cookie` und `Set-Cookie` auch dann,
  wenn sie auf der Allowlist stehen), Werte unter geheimen Namen wie `password`, `token` oder
  `api_key`, Pfadsegmente, die wie Kennungen aussehen (als `:id` angezeigt), und Datei-Parts von
  Multipart-Bodys.
- **Schlüssel, die kein reines ASCII sind**, nachdem Escapes dekodiert, NFKC angewendet und
  Groß-/Kleinschreibung angeglichen wurde (`pаssword` mit kyrillischem `а`, `pass\u200Dword`,
  `şifre`), haben standardmäßig verborgene Werte.
- **Bodys, die sich nicht parsen lassen** (ein unbekannter oder fehlender Content-Type, fehlerhaftes
  JSON oder Multipart, ein an der Größengrenze abgeschnittener Body), werden durch einen Hinweis wie
  `[body omitted: 512 bytes, application/xml]` ersetzt.
- **Log-Meldungen** werden bis zu ihrem ersten Auslöser gespeichert: Ein geheimer Name, ein
  Schlüssel, der nicht auf der Allowlist steht (standardmäßig `status`, `method`, `path`,
  `duration_ms` und `count`; eigene fügen Sie mit `allowedTextKeys` hinzu), ein Zeichen außerhalb
  von ASCII, das weder Buchstabe noch diakritisches Zeichen, Ziffer oder Leerzeichen ist (`꞉`,
  `…`, ein Emoji), eine Escape-Sequenz wie `%3D` oder ein Anführungszeichen oder eine Klammer, die
  nicht schließt, schwärzt alles danach, auch die Zeilen darunter
  (`login password=hunter2 status=200` wird als `login password=[REDACTED]` gespeichert,
  `x=hunter2` als `x=[REDACTED]`). Eine Meldung ohne Auslöser bleibt, wie sie ist, bis auf
  erkannte Tokens, Kartennummern und E-Mail-Adressen.
- **URLs in Log-Meldungen** haben keine Insel-Logik. Eine URL bleibt nur sichtbar, wenn sie sauber
  ist: `scheme://host` mit einem optionalen Pfad aus ASCII-Buchstaben, Ziffern, `.`, `_`, `-` und
  `/`, ohne Host oder Pfadsegment, das ein geheimer Name ist, und danach ein Leerzeichen, ein
  Zeilenende oder ein Satzzeichen, das einen Satz beendet. Jede andere URL (eine Query, ein
  Fragment, ein Port, Benutzerdaten, ein Escape wie `%3D`) verbirgt die Meldung ab dem Anfang der
  URL (`GET https://api.example.com/v1/items?page=2 done` wird als `GET [REDACTED]` gespeichert);
  `allowedQueryParameters` gilt für aufgezeichnete Request-URLs, nicht für URLs im Text.

Schwärzen ist ein Sicherheitsnetz, keine Garantie. Es ist für Geheimnisse gebaut, die versehentlich
aufgezeichnet werden: Strukturierte Eingaben werden geparst, und was der Parser nicht vollständig
versteht, wird geschwärzt; Freitext ist ein bestmöglicher Versuch, und ein geheimer Name, der ohne
`=` oder `:` geschrieben ist und in dem zwei oder mehr Buchstaben durch ähnlich aussehende ersetzt
sind (`pɑsswoʀd hunter2`), wird nicht sicher gefunden. Halte Geheimnisse von vornherein aus den
aufgezeichneten Anfragen und aus Log-Meldungen heraus, und bevorzuge strukturiertes Logging.

Zwei weitere Grenzen gehören zu diesem Modell. **Kostengrenze:** Alle in einer Eingabe
verschachtelten Dokumente (JSON in einem String, eine URL im Text) lesen zusammen höchstens das
Vierfache der Länge der Eingabe; jenseits dieses Budgets wird der String, der das nächste
Dokument enthält, vollständig verborgen. **Mehrzeilige Layouts** brauchen nichts Besonderes: Ein
Property-List-`<key>` in einer eigenen Zeile, JSON über mehrere Zeilen und ein als Text
geschriebener Multipart-Body werden ab dem ersten Auslöser bis zum Ende des Textes verborgen, der
Wert also, wo immer er steht.

### Meldungen loggen

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### Anfragen und Reports exportieren

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

Die Teilen-Menüs der Konsole erledigen dasselbe für den Nutzer: **Export HAR** im Network-Tab,
**Share as cURL** in einer Anfrage und **Share Report** im Device-Tab.

### Auf macOS verwenden

Eine Mac-App kennt kein Schütteln. Gib der Konsole ein eigenes Fenster und öffne sie mit einem
Tastenkürzel:

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
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="Der Logs-Tab mit info-, warning- und error-Meldungen aus der Beispiel-App, jeweils mit Kategorie, Uhrzeit und Quellzeile"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="Der Device-Tab mit App-Version, iOS-Version, simuliertem Modell, Speicher, App-Speicher, thermischem Zustand, Low Power Mode und Debugger-Status"></picture></td>
</tr>
</table>

Die Screenshots stammen aus der [Beispiel-App](Examples) auf einem iPhone-17-Pro-Simulator mit iOS 27
und wurden von [`scripts/capture-screens.sh`](scripts/capture-screens.sh) aufgenommen. Die Anfragen sind
echt: Die App sendet sie an `api.github.com` und `postman-echo.com`. Öffne zum Ausführen
`Examples/DevToolsDemo/DevToolsDemo.xcodeproj`, wähle einen iPhone-Simulator oder **My Mac**, starte
die App und tippe auf **Send All**.

## Dokumentation

API-Referenz und Artikel:

- [API-Referenz](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — jeder öffentliche Typ mit seinen Parametern und Grenzen.

## Anleitungen

- [Erste Schritte](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — Paket hinzufügen, Aufzeichnung starten, Konsole öffnen, Meldungen loggen.
- [Netzwerkverkehr aufzeichnen](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — welche Sessions aufgezeichnet werden, wie Anfragen den Server erreichen, Speichergrenzen und was nicht aufgezeichnet wird.
- [Sensible Daten schwärzen](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — was gespeichert wird und was nie, wie Schlüssel abgeglichen werden, warum manche Bodys ausgelassen werden, und die Grenzen.
- [Die Tools aus Release-Builds heraushalten](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — Compilation Conditions und ein eigenes internes Target.

## Voraussetzungen

| Plattform | Mindestversion |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| Toolchain | Swift 6.2 · Xcode 26+ |

Die Schüttelgeste gibt es nur unter iOS; unter macOS öffnet sich die Konsole in einem Fenster oder
einer Sheet.

## Architektur

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture` registriert `CaptureProtocol`, ein `URLProtocol`, für `URLSession.shared` und fügt
  es den default- und ephemeral-Konfigurationen hinzu. Das Protokoll leitet jede Anfrage über eine
  interne `URLSession` weiter und ruft die Session der App auf dem Thread zurück, der den Ladevorgang
  gestartet hat.
- `RedactionPolicy` läuft, bevor ein `NetworkEntry` erstellt wird, sodass Speicher und Exporte nur
  geschwärzte Werte sehen.
- `NetworkLogger` und `LogStore` sind sperrengeschützte Ringpuffer, die Änderungen über einen
  `AsyncStream` veröffentlichen; die Observable-Modelle der Konsole lesen sie höchstens etwa siebenmal
  pro Sekunde.
- Alles außerhalb der Konsolen-Views ist `Sendable` und von jedem Thread aus aufrufbar.

## Roadmap

Geplant, in keiner festen Reihenfolge: Anfragen über App-Starts hinweg behalten, ein `swift-log`-Backend
für `LogStore`, tvOS- und visionOS-Unterstützung für die Konsole sowie das Mocken von Anfragen.
Vorschläge sind in den [Issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
willkommen.

## Mitwirken

Beiträge sind willkommen. Lies vor einem Pull Request den [Leitfaden für Beiträge](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md) und den [Verhaltenskodex](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md). Sicherheitsprobleme meldest du vertraulich, wie in der [Sicherheitsrichtlinie](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md) beschrieben.

## Lizenz

Veröffentlicht unter der MIT-Lizenz. Siehe [LICENSE](LICENSE).
