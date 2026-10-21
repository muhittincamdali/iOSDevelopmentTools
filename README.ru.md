<!-- i18n-source: README.md@35e61d77773f37038a6c7b618c6465a324f8f277 status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ru-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ru-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ru-light.svg" alt="iOSDevelopmentTools: Сетевые запросы, логи и состояние устройства вашего приложения во встроенной консоли, секреты скрыты."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="Статус CI"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="Последняя версия: v2.1.0"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="Поддерживаемые платформы: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="Версия языка: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="Лицензия: MIT"></picture></a>
</p>

<p align="center">
<a href="#быстрый-старт"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ru-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ru-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ru-light.svg" alt="Начать"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ru-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ru-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ru-light.svg" alt="Документация"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ru-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ru-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ru-light.svg" alt="Примеры"></picture></a>
</p>

> Это перевод README на английском языке. Если они расходятся, актуальна английская версия.

<!-- brand:end -->

Swift-пакет, который встраивает консоль отладки в ваше приложение для iOS или macOS. Он записывает
запросы, которые приложение выполняет через `URLSession`, хранит ваши сообщения журнала и собирает отчёт
об устройстве, а затем показывает всё это в консоли на SwiftUI. Консоль открывается встряхиванием,
кнопкой или в отдельном окне. Откройте запрос, чтобы увидеть его заголовки, тела и время выполнения,
или поделитесь им как командой cURL либо файлом HAR для инструментов разработчика в браузере, Charles
или Proxyman. Пароли, токены, cookie и API-ключи заменяются до того, как что-либо будет сохранено,
поэтому они не попадают ни в консоль, ни в экспортированный файл, ни на скриншот в баг-репорте. Пакет
предназначен для debug- и тестовых сборок, не имеет зависимостей и написан с расчётом на strict
concurrency в Swift 6.

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="Вкладка Network со списком семи реальных запросов из демонстрационного приложения: неудачный запрос к неизвестному хосту, ответы 503 и 404 и четыре успешных запроса с указанием длительности и размера"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="Запрос входа, открытый в консоли: заголовок Authorization и пароль в теле JSON показаны как [REDACTED]"></picture>
</p>

## Основные возможности

- **Одна строка для записи** — `NetworkCapture.start()` записывает `URLSession.shared` и все сессии,
  которые создаются потом из конфигурации default или ephemeral, включая библиотеки, построенные на
  `URLSession`. Ваше приложение получает каждый ответ без изменений.
- **Маскирование до сохранения** — значения под секретными именами (`password`, `token`, `api_key`,
  как бы они ни были написаны или закодированы) и под ключами, которые не являются простым ASCII,
  заменяются, а свои значения сохраняют только заголовки и параметры query из разрешённого списка.
  Тела JSON, форм и multipart разбираются; тело, которое нельзя разобрать, заменяется пометкой
  вместо сохранения. В сообщении журнала маскируется всё от первого секретного имени или ключа
  не из списка разрешённых до конца.
- **Ограниченный объём хранения** — по умолчанию не более 500 запросов и 256 KiB на каждое тело;
  сообщения журнала хранятся в кольцевом буфере, а загрузки больше 4 MiB передаются потоком, а не
  копируются. Заголовки и URL сохраняются целиком.
- **Экспорт** — любой запрос как безопасная для оболочки команда `curl`, любой список запросов как
  HTTP Archive (HAR 1.2).
- **Логи и отчёт об устройстве** — `LogStore` хранит сообщения с уровнем и категорией и дополнительно
  записывает их в единую систему журналирования (unified logging); `DeviceSnapshot` сообщает версию,
  ОС, модель, объём занятой памяти, тепловое состояние и подключён ли отладчик.
- **Протестировано** — 631 тест Swift Testing на macOS и 628 в симуляторе iOS. Запросы идут из
  сессии приложения через перехват на stub-сервер, а тесты проверяют, что получил сервер, что получило
  приложение и что было сохранено.

## Быстрый старт

**1. Добавьте пакет**

В Xcode выберите **File › Add Package Dependencies…** и введите адрес репозитория:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Вставьте его в поле поиска в правом верхнем углу окна. Оставьте **Dependency Rule** равным
**Up to Next Major Version** начиная с `2.1.0` и нажмите **Add Package**. В следующем окне выберите
target вашего приложения рядом с **iOSDevelopmentTools** и снова нажмите **Add Package**.

**2. Импортируйте модуль**

```swift
import iOSDevelopmentTools
```

Поместите эту строку в начало файла, где объявлен ваш `App`, под `import SwiftUI`.

**3. Запустите запись и добавьте консоль**

В файле `App` вашего приложения запустите перехват в `init` и добавьте консоль к корневому view.
Строки `#if DEBUG` не пускают оба вызова в release-сборки:

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

Запустите приложение в симуляторе iPhone, дождитесь любого запроса и выберите **Device › Shake** в
меню Simulator. Консоль откроется на вкладке Network, и запрос будет в списке.

`devToolsConsoleOnShake()` доступен только в iOS. Если приложение собирается и для macOS,
оберните его в `#if DEBUG && os(iOS)` и откройте консоль в отдельном окне, как показано ниже в
разделе **Использование на macOS**.

## Установка

### Swift Package Manager

В Xcode выберите **File › Add Package Dependencies…** и введите адрес репозитория:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Или добавьте его в `dependencies` вашего `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOSDevelopmentTools.git", from: "2.1.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "iOSDevelopmentTools", package: "iOSDevelopmentTools")
    ])
]
```

## Использование

Примеры ниже скопированы из
[ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift); этот файл компилируют
демонстрационное приложение и набор тестов.

### Открыть консоль по кнопке

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### Записывать сессию, которую вы создаёте сами

Сессии, созданные из `.default` или `.ephemeral` после `NetworkCapture.start()`, записываются
автоматически. Для сессии, созданной раньше, добавьте запись в её конфигурацию:

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### Выбрать, что сохранять

Значения лимитов вне допустимых диапазонов приводятся к границам диапазона. Секретные имена
нормализуются так же, как ключи, с которыми их сравнивают, поэтому `"license_number"` ловит и
`licenseNumber`, и `LICENSE-NUMBER`, а значения сохраняют только перечисленные параметры query:

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

### Что записывается

- **Записывается:** метод, статус, время, имена заголовков, значения заголовков из разрешённого
  списка (по умолчанию `Accept`, `Accept-Encoding`, `Accept-Language`, `Cache-Control`,
  `Content-Encoding`, `Content-Length`, `Content-Type`, `ETag` и `User-Agent`), схема, хост, путь
  и имена параметров query в URL, а также тела JSON, форм, multipart и `text/plain` после
  маскирования.
- **Никогда не записывается:** данные пользователя и фрагмент URL, значения query вне
  разрешённого списка, значения всех остальных заголовков (`Authorization`, `Cookie` и
  `Set-Cookie` даже из разрешённого списка), значения под секретными именами вроде `password`,
  `token` или `api_key`, сегменты пути, похожие на идентификаторы (показываются как `:id`), и сегмент после
  сегмента, который называет секрет или не является простым ASCII (`/caf%C3%A9/menu` сохраняется
  как `/caf%C3%A9/:id`), путь и запрос URL с
  точечным сегментом (`/pin/./4831`, `..`, `%2E`) или `;` (`/cart;jsessionid=…`, `%3B`): сохраняются
  только схема и хост, так что матричные параметры никогда не разбираются; путь и запрос после
  хоста, который называет секрет (`myapp://pin/4831` сохраняется как `myapp://pin`; хост вроде
  `auth.example.com` тоже скрывает свой путь); и файловые части тел multipart.
- **Ключи, которые не являются простым ASCII** после декодирования escape-последовательностей,
  NFKC и приведения регистра (`pаssword` с кириллической `а`, `pass\u200Dword`, `şifre`), по
  умолчанию скрывают своё значение.
- **Тела, которые нельзя разобрать** (неизвестный или отсутствующий тип содержимого, повреждённый
  JSON или multipart, тело, обрезанное на пределе размера), заменяются пометкой вроде
  `[body omitted: 512 bytes, application/xml]`.
- **Сообщения журнала** сохраняются до первого триггера: секретное имя, ключ не из списка
  разрешённых (по умолчанию `status`, `method`, `path`, `duration_ms` и `count`; свои ключи
  добавляются через `allowedTextKeys`), символ вне ASCII, который не является буквой, диакритикой,
  цифрой или пробелом (`꞉`, `…`, эмодзи, а также буква, которую нормализация совместимости
  читает как знак препинания, например `🄁` как `0,`), escape-последовательность любого вида
  (обратная косая черта перед чем угодно, кроме пробельного символа, `%3D`, `&` перед буквой или
  `#`: `R&D`, `&amp`), ключ в кавычках
  не из списка разрешённых (текст обрезается по открывающей кавычке: `"x":"hunter2"` сохраняется
  как `[REDACTED]`), разметка (`<`, который не является сравнением: `<b>`, `</x>`, `<!--`; ни один
  тег не сохраняет свой текст), кавычка, не закрытая в своей строке, перекрывающиеся кавычки
  (`'x "y' z"`) или незакрытая скобка
  скрывают всё, что идёт после, включая строки ниже
  (`login password=hunter2 status=200` сохраняется как `login password=[REDACTED]`, а `x=hunter2`
  как `x=[REDACTED]`). Сообщение без триггера сохраняется как есть, кроме найденных токенов, номеров
  карт и адресов почты.
  Детекторы читают через VT, FF, U+0085, U+2028 и U+2029, которые обрезают сообщение, поэтому
  номер карты, IBAN, адрес почты или токен, разделённый одним из них, скрывается с начала
  (`paid 4111 1111 1111`, U+2028, `1111` сохраняется как `paid [REDACTED]`); LF и CR завершают
  найденное значение.
- **URL в сообщениях лога** не обрабатываются как отдельный островок. URL остаётся видимым, только
  если он чистый: `scheme://host` с необязательным путём из ASCII-букв, цифр, `.`, `_`, `-` и `/`,
  без хоста или сегмента пути, который является секретным именем, а после него стоит пробел, конец
  строки, конец текста или ровно один из знаков `.`, `,`, `!` и `)`, за которым идёт одно из
  этого. Любой другой URL (с запросом, фрагментом, портом, данными пользователя, экранированием
  вроде `%3D`, кавычкой или двумя знаками после него) скрывает сообщение с того места, где начинается
  URL (`GET https://api.example.com/v1/items?page=2 done` сохраняется как `GET [REDACTED]`);
  `allowedQueryParameters` применяется к URL записанных запросов, а не к URL в тексте.

Маскирование — это страховка, а не гарантия. Оно рассчитано на секреты, записанные по ошибке:
структурированные данные разбираются парсером, и всё, что парсер не понимает полностью, скрывается;
свободный текст обрабатывается по возможности, и секретное имя, записанное без `=` или `:`, в
котором две или более буквы заменены похожими (`pɑsswoʀd hunter2`), не обязательно будет
найдено; одна буква, комбинируемый знак или цифра без формы в ASCII считается любой буквой,
поэтому `tͦken hunter2`, `passw〇rd hunter2` и `t၀ken hunter2` (мьянманский ноль)
находятся.
Не допускайте секретов в записываемых запросах и сообщениях журнала с самого начала и используйте
структурированное журналирование.

К этой модели относятся ещё два ограничения. **Предел затрат:** все документы, вложенные в один
вход (JSON в строке, URL в тексте), вместе читают не больше четырёх длин входа; сверх этого
бюджета строка, содержащая следующий документ, скрывается целиком. **Многострочная разметка** не
требует ничего особого: `<key>` property list на отдельной строке, JSON на нескольких строках и
multipart-тело, записанное как текст, скрываются от первого триггера до конца текста, так что
значение скрыто, где бы оно ни было записано.

### Записывать сообщения в журнал

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### Экспортировать запросы и отчёты

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

Меню «Поделиться» в консоли делают то же самое для пользователя: **Export HAR** на вкладке Network,
**Share as cURL** в запросе, **Share Report** на вкладке Device.

### Использование на macOS

У приложения для Mac нет встряхивания. Дайте консоли отдельное окно и откройте его сочетанием клавиш:

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

## Демо

<table>
<tr>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="Вкладка Logs с сообщениями info, warning и error из демонстрационного приложения; у каждого указаны категория, время и строка исходного кода"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="Вкладка Device с версией приложения, версией iOS, имитируемой моделью, памятью, памятью приложения, тепловым состоянием, Low Power Mode и состоянием отладчика"></picture></td>
</tr>
</table>

Скриншоты сделаны в [демонстрационном приложении](Examples) на симуляторе iPhone 17 Pro с iOS 27 с
помощью [`scripts/capture-screens.sh`](scripts/capture-screens.sh). Запросы настоящие: приложение
отправляет их на `api.github.com` и `postman-echo.com`. Чтобы запустить его, откройте
`Examples/DevToolsDemo/DevToolsDemo.xcodeproj`, выберите симулятор iPhone или **My Mac**, запустите и
нажмите **Send All**.

## Документация

Справочник API и статьи:

- [Справочник API](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — каждый публичный тип с параметрами и ограничениями.

## Руководства

- [Начало работы](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — добавить пакет, запустить перехват, открыть консоль, записывать сообщения в журнал.
- [Перехват сетевого трафика](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — какие сессии записываются, как запросы доходят до сервера, лимиты памяти и что не записывается.
- [Маскирование чувствительных данных](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — что записывается и что не записывается никогда, как сопоставляются ключи, почему некоторые тела опускаются, и ограничения.
- [Как не включать инструменты в release-сборки](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — условия компиляции и отдельный внутренний target.

## Требования

| Платформа | Минимальная версия |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| Инструменты | Swift 6.2 · Xcode 26+ |

Жест встряхивания есть только в iOS; в macOS консоль открывается в окне или в sheet.

## Архитектура

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture` регистрирует `CaptureProtocol`, то есть `URLProtocol`, для `URLSession.shared` и
  добавляет его в конфигурации default и ephemeral. Протокол отправляет каждый запрос дальше через одну
  внутреннюю `URLSession` и вызывает сессию приложения обратно в потоке, который начал загрузку.
- `RedactionPolicy` срабатывает до создания `NetworkEntry`, поэтому хранилища и экспорт видят только
  замаскированные значения.
- `NetworkLogger` и `LogStore` — кольцевые буферы под защитой блокировок, которые публикуют изменения
  через `AsyncStream`; observable-модели консоли читают их не чаще примерно семи раз в секунду.
- Всё за пределами view консоли — `Sendable` и может вызываться из любого потока.

## План развития

В планах, без определённого порядка: сохранение запросов между запусками, бэкенд `swift-log` для
`LogStore`, поддержка консоли на tvOS и visionOS и подмена запросов (mocking). Предложения приветствуются
в [issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues).

## Участие в разработке

Мы рады вашему участию. Перед открытием pull request прочитайте [руководство для участников](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md) и [кодекс поведения](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md). О проблемах безопасности сообщайте конфиденциально, как описано в [политике безопасности](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md).

## Лицензия

Распространяется по лицензии MIT. Подробнее — в файле [LICENSE](LICENSE).
