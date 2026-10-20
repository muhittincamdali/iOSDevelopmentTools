<!-- i18n-source: README.md@40fa9f43d9be0ee871a02eb5666a1b1aa978ed70 status=reviewed -->
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
- **Ocultación antes de guardar** — se sustituyen los valores bajo nombres secretos (`password`,
  `token`, `api_key`, se escriban o codifiquen como sea) y bajo claves que no son ASCII simple, y
  solo las cabeceras y los parámetros de query de la lista permitida conservan su valor. Los
  cuerpos JSON, de formulario y multipart se analizan; un cuerpo que no se puede analizar se
  sustituye por una nota en lugar de guardarse. En un mensaje de registro se oculta todo desde el
  primer nombre secreto, o la primera clave que no está en la lista permitida, hasta el final.
- **Almacenamiento acotado** — por defecto, como máximo 500 solicitudes y 256 KiB de cada cuerpo; los
  mensajes de log van a un búfer circular y las subidas de más de 4 MiB se transmiten en streaming en
  lugar de copiarse. Las cabeceras y las URL se guardan completas.
- **Exportación** — cualquier solicitud como comando `curl` seguro para el shell y cualquier lista de
  solicitudes como HTTP Archive (HAR 1.2).
- **Logs e informe del dispositivo** — `LogStore` guarda mensajes con nivel y categoría y también los
  escribe en el sistema de registro unificado (unified logging); `DeviceSnapshot` informa de la
  versión, el sistema operativo, el modelo, el consumo de memoria, el estado térmico y si hay un
  depurador conectado.
- **Probado** — 516 tests de Swift Testing en macOS y 513 en un simulador de iOS. Las solicitudes van
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

Los límites fuera de rango se ajustan al rango. Los nombres secretos se normalizan igual que las
claves con las que se comparan, así que `"license_number"` también detecta `licenseNumber` y
`LICENSE-NUMBER`, y solo los parámetros de query indicados conservan su valor:

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

### Qué se guarda

- **Se guarda:** el método, el estado, los tiempos, los nombres de las cabeceras, los valores de
  las cabeceras de la lista permitida (por defecto `Accept`, `Accept-Encoding`, `Accept-Language`,
  `Cache-Control`, `Content-Encoding`, `Content-Length`, `Content-Type`, `ETag` y `User-Agent`),
  el esquema, el host, la ruta y los nombres de los parámetros de query de la URL, y los cuerpos
  JSON, de formulario, multipart y `text/plain` después de ocultar.
- **Nunca se guarda:** la información de usuario y el fragmento de la URL, los valores de query
  que no están en la lista permitida, los valores de todas las demás cabeceras (`Authorization`,
  `Cookie` y `Set-Cookie` aunque estén en la lista), los valores bajo nombres secretos como
  `password`, `token` o `api_key`, los segmentos de ruta que parecen identificadores (se muestran
  como `:id`) y las partes de archivo de los cuerpos multipart.
- **Las claves que no son ASCII simple** una vez decodificados los escapes, aplicada NFKC e
  igualadas mayúsculas y minúsculas (`pаssword` con una `а` cirílica, `pass\u200Dword`, `şifre`)
  tienen su valor oculto por defecto.
- **Los cuerpos que no se pueden analizar** (un tipo de contenido desconocido o ausente, JSON o
  multipart mal formado, un cuerpo cortado en el límite de tamaño) se sustituyen por una nota como
  `[body omitted: 512 bytes, application/xml]`.
- **Los mensajes de registro** se guardan hasta su primer disparador: un nombre secreto, una clave
  que no está en la lista permitida (`status`, `method`, `path`, `duration_ms` y `count` por
  defecto; añade las tuyas con `allowedTextKeys`), un carácter fuera de ASCII que no es una letra,
  una marca, un dígito ni un espacio (`꞉`, `…`, un emoji), una secuencia de escape como `%3D`, o
  una comilla o un corchete que no se cierra oculta todo lo que viene después, también las líneas
  siguientes (`login password=hunter2 status=200` se guarda como `login password=[REDACTED]`, y
  `x=hunter2` como `x=[REDACTED]`). Un mensaje sin disparador se guarda tal cual, salvo los tokens,
  los números de tarjeta y las direcciones de correo detectados.
- **Las URL en los mensajes de log** no tienen lógica de isla. Una URL solo queda visible si está
  limpia: `scheme://host` con una ruta opcional de letras ASCII, dígitos, `.`, `_`, `-` y `/`, sin
  host ni segmento de ruta que sea un nombre secreto, y seguida de un espacio, un fin de línea o un
  signo que cierra una frase. Cualquier otra URL (una query, un fragmento, un puerto, información
  de usuario, un escape como `%3D`) oculta el mensaje desde donde empieza la URL
  (`GET https://api.example.com/v1/items?page=2 done` se guarda como `GET [REDACTED]`);
  `allowedQueryParameters` se aplica a las URL de las solicitudes registradas, no a las URL en el
  texto.

La ocultación es una red de seguridad, no una garantía. Está pensada para secretos registrados por
accidente: la entrada estructurada se analiza, y lo que el analizador no entiende del todo se
oculta; el texto libre es un mejor esfuerzo, y no se garantiza encontrar un nombre secreto
disfrazado con letras parecidas y escrito sin `=` ni `:` (`pɑsswoʀd hunter2`). Mantén los secretos
fuera de las solicitudes que registras y de los mensajes de registro desde el principio, y
prefiere el registro estructurado.

Dos límites más forman parte de ese modelo. **Límite de coste:** todos los documentos anidados
en una entrada (JSON dentro de una cadena, una URL en un texto) leen juntos como mucho cuatro veces
la longitud de la entrada; pasado ese presupuesto, la cadena que contiene el siguiente documento se
oculta entera. **Los formatos de varias líneas** no necesitan nada especial: un `<key>` de property
list en su propia línea, un JSON repartido en varias líneas y un cuerpo multipart escrito como
texto se ocultan desde el primer disparador hasta el final del texto, así que el valor queda oculto
esté donde esté.

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
  — qué se guarda y qué nunca se guarda, cómo se comparan las claves, por qué se omiten algunos cuerpos y los límites.
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
