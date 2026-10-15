<!-- i18n-source: README.md@53235c68509fd5717e98f781085334b9f8ac8996 status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-es-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-es-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-es-light.svg" alt="iOSDevelopmentTools: Solicitudes de red, registros y estado del dispositivo de tu app en una consola integrada, con secretos ocultos."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="Estado de CI"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="Última versión: v2.0.0"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="Plataformas compatibles: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="Versión del lenguaje: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="Licencia: MIT"></picture></a>
</p>

<p align="center">
<a href="#inicio-rápido"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-es-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-es-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-es-light.svg" alt="Empezar"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-es-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-es-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-es-light.svg" alt="Documentación"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-es-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-es-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-es-light.svg" alt="Ejemplos"></picture></a>
</p>

> Esta es una traducción del README en inglés. Si hay diferencias, la versión en inglés es la vigente.

<!-- brand:end -->

Un paquete de Swift que incorpora una consola de depuración dentro de tu app de iOS o macOS. Registra
las solicitudes que tu app hace con `URLSession`, guarda tus mensajes de log y recoge un informe del
dispositivo, y muestra los tres en una consola de SwiftUI que se abre al agitar el dispositivo, con un
botón o en una ventana. Abre una solicitud para ver sus cabeceras, cuerpos y tiempos, o compártela como
comando cURL o como archivo HAR para las herramientas de desarrollo del navegador, Charles o Proxyman.
Las contraseñas, los tokens, las cookies y las claves de API se sustituyen antes de guardar nada, de
modo que no acaban en la consola, en un archivo exportado ni en una captura de pantalla de un informe
de error. Está pensado para compilaciones de depuración y de pruebas, no tiene dependencias y está
escrito para la strict concurrency de Swift 6.

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="La pestaña Network con siete solicitudes reales de la app de ejemplo: una solicitud fallida a un host desconocido, un 503, un 404 y cuatro solicitudes correctas con su duración y tamaño"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="Una solicitud de inicio de sesión abierta en la consola: la cabecera Authorization y la contraseña del cuerpo JSON muestran [REDACTED]"></picture>
</p>

## Lo más destacado

- **Una línea para registrar** — `NetworkCapture.start()` registra `URLSession.shared` y todas las
  sesiones que se creen después con la configuración default o ephemeral, incluidas las bibliotecas
  basadas en `URLSession`. Tu app recibe cada respuesta sin cambios.
- **Ocultación antes de guardar** — los valores de cabeceras, query, formularios, multipart y JSON con
  nombres sensibles se sustituyen, sea cual sea la grafía del nombre (`X-API-Key`, `api_key`,
  `API%5FKEY`). Un cuerpo JSON que no se puede comprobar, por ejemplo porque está cortado, se retiene
  en lugar de guardarse sin comprobar.
- **Uso de memoria fijo** — por defecto, como máximo 500 solicitudes y 256 KiB de cada cuerpo; los
  mensajes de log van a un búfer circular y las subidas de más de 4 MiB se transmiten en streaming en
  lugar de copiarse.
- **Exportación** — cualquier solicitud como comando `curl` seguro para el shell y cualquier lista de
  solicitudes como HTTP Archive (HAR 1.2).
- **Logs e informe del dispositivo** — `LogStore` guarda mensajes con nivel y categoría y también los
  escribe en el sistema de registro unificado (unified logging); `DeviceSnapshot` informa de la
  versión, el sistema operativo, el modelo, el consumo de memoria, el estado térmico y si hay un
  depurador conectado.
- **Probado** — 126 tests de Swift Testing en macOS y 127 en un simulador de iOS. Las solicitudes van
  de una sesión de la app, a través de la captura, a un servidor stub, y los tests comprueban qué
  recibió el servidor, qué recibió la app y qué se guardó.

## Inicio rápido

**1. Añade el paquete**

En Xcode, elige **File › Add Package Dependencies…** e introduce la URL del repositorio:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Pégala en el campo de búsqueda de la esquina superior derecha de la ventana. Deja **Dependency Rule**
en **Up to Next Major Version** desde `2.0.0` y haz clic en **Add Package**. En la ventana siguiente,
elige el target de tu app junto a **iOSDevelopmentTools** y vuelve a hacer clic en **Add Package**.

**2. Importa el módulo**

```swift
import iOSDevelopmentTools
```

Pon esta línea al principio del archivo que declara tu `App`, debajo de `import SwiftUI`.

**3. Empieza a registrar y añade la consola**

En el archivo `App` de tu app, inicia la captura en `init` y añade la consola a la vista raíz. Las
líneas `#if DEBUG` mantienen ambas fuera de las compilaciones de release:

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

Ejecuta la app en un simulador de iPhone, haz que envíe una solicitud y elige **Device › Shake** en el
menú de Simulator. La consola se abre en la pestaña Network con la solicitud en la lista.

`devToolsConsoleOnShake()` solo existe en iOS. Si tu app también se compila para macOS, rodéalo
con `#if DEBUG && os(iOS)` y abre la consola en una ventana, como se muestra más abajo en
**Usarlo en macOS**.

## Instalación

### Swift Package Manager

En Xcode, elige **File › Add Package Dependencies…** e introduce la URL del repositorio:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

O añádelo a las `dependencies` de tu `Package.swift`:

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

## Uso

Los ejemplos de abajo están copiados de
[ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift), que compilan la app de
ejemplo y la suite de tests.

### Abrir la consola desde un botón

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### Registrar una sesión que creas tú mismo

Las sesiones creadas con `.default` o `.ephemeral` después de `NetworkCapture.start()` se registran
automáticamente. Para una sesión creada antes, añade el registro a su configuración:

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### Elegir qué se conserva

Los límites fuera de rango se ajustan al rango. Los fragmentos de nombre se comparan con nombres
normalizados, así que `"iban"` también detecta `IBAN`, `iban_number` e `ibanNumber`:

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

### Registrar mensajes

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### Exportar solicitudes e informes

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

Los menús de compartir de la consola hacen lo mismo por el usuario: **Export HAR** en la pestaña
Network, **Share as cURL** en una solicitud y **Share Report** en la pestaña Device.

### Usarlo en macOS

Una app de Mac no tiene gesto de agitar. Dale a la consola una ventana propia y ábrela con un atajo:

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
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="La pestaña Logs con mensajes info, warning y error de la app de ejemplo, cada uno con su categoría, hora y línea de origen"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="La pestaña Device con la versión de la app, la versión de iOS, el modelo simulado, la memoria, la memoria de la app, el estado térmico, el Low Power Mode y el estado del depurador"></picture></td>
</tr>
</table>

Las capturas proceden de la [app de ejemplo](Examples) en un simulador de iPhone 17 Pro con iOS 27 y
se hicieron con [`scripts/capture-screens.sh`](scripts/capture-screens.sh). Las solicitudes son reales:
la app las envía a `api.github.com` y `postman-echo.com`. Para ejecutarla, abre
`Examples/DevToolsDemo/DevToolsDemo.xcodeproj`, elige un simulador de iPhone o **My Mac**, ejecútala y
toca **Send All**.

## Documentación

Referencia de la API y artículos:

- [Referencia de la API](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — todos los tipos públicos con sus parámetros y límites.

## Guías

- [Primeros pasos](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — añadir el paquete, iniciar la captura, abrir la consola y registrar mensajes.
- [Captura del tráfico de red](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — qué sesiones se registran, cómo llegan las solicitudes al servidor, límites de memoria y qué no se registra.
- [Ocultación de datos sensibles](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — cómo se comparan los nombres, qué se sustituye, por qué algunos cuerpos se retienen y los límites.
- [Mantener las herramientas fuera de las compilaciones de release](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — condiciones de compilación y un target interno aparte.

## Requisitos

| Plataforma | Versión mínima |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| Herramientas | Swift 6.2 · Xcode 26+ |

El gesto de agitar solo existe en iOS; en macOS la consola se abre en una ventana o en una sheet.

## Arquitectura

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture` registra `CaptureProtocol`, un `URLProtocol`, para `URLSession.shared` y lo añade a
  las configuraciones default y ephemeral. El protocolo envía cada solicitud a través de una
  `URLSession` interna y devuelve la llamada a la sesión de la app en el hilo que inició la carga.
- `RedactionPolicy` se ejecuta antes de crear un `NetworkEntry`, de modo que los almacenes y las
  exportaciones solo ven valores ocultados.
- `NetworkLogger` y `LogStore` son búferes circulares protegidos con bloqueos que publican los cambios
  mediante un `AsyncStream`; los modelos observables de la consola los leen como mucho unas siete veces
  por segundo.
- Todo lo que queda fuera de las vistas de la consola es `Sendable` y se puede llamar desde cualquier
  hilo.

## Hoja de ruta

Previsto, sin un orden fijo: conservar las solicitudes entre ejecuciones, un backend de `swift-log` para
`LogStore`, compatibilidad de la consola con tvOS y visionOS, y mocking de solicitudes. Las sugerencias
son bienvenidas en [issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues).

## Contribuir

Las contribuciones son bienvenidas. Lee la [guía de contribución](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md) y el [código de conducta](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md) antes de abrir una pull request. Informa de los problemas de seguridad de forma privada, como se describe en la [política de seguridad](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md).

## Licencia

Publicado bajo la licencia MIT. Consulta [LICENSE](LICENSE).
