<!-- i18n-source: README.md@46cdddcee504e0c7ba46c8a005fb8ad9dd742676 status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-tr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-tr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-tr-light.svg" alt="iOSDevelopmentTools: Uygulamanızın ağ istekleri, günlükleri ve cihaz durumu uygulama içi bir konsolda; gizli bilgiler maskelenir."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="CI durumu"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="Son sürüm: v2.0.0"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="Desteklenen platformlar: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="Dil sürümü: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="Lisans: MIT"></picture></a>
</p>

<p align="center">
<a href="#hızlı-başlangıç"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-tr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-tr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-tr-light.svg" alt="Başlayın"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-tr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-tr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-tr-light.svg" alt="Dokümantasyon"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-tr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-tr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-tr-light.svg" alt="Örnekler"></picture></a>
</p>

> Bu belge İngilizce README'nin çevirisidir. İkisi arasında fark varsa güncel olan İngilizce sürümdür.

<!-- brand:end -->

iOS veya macOS uygulamanızın içine bir hata ayıklama konsolu yerleştiren bir Swift paketi.
Uygulamanızın `URLSession` ile yaptığı istekleri kaydeder, günlük mesajlarınızı tutar ve bir cihaz
raporu toplar; üçünü de sallama hareketiyle, bir düğmeyle ya da ayrı bir pencerede açılan SwiftUI
konsolunda gösterir. Header'ları, gövdeleri ve süreleri görmek için bir isteği açın; isterseniz
cURL komutu olarak ya da tarayıcı geliştirici araçları, Charles veya Proxyman için HAR dosyası
olarak paylaşın. Parolalar, token'lar, çerezler ve API anahtarları hiçbir şey saklanmadan önce
değiştirilir; bu yüzden konsolda, dışa aktarılan bir dosyada ya da hata raporundaki ekran
görüntüsünde görünmez. Debug ve test derlemeleri için tasarlanmıştır, bağımlılığı yoktur ve
Swift 6 strict concurrency ile uyumlu yazılmıştır.

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="Örnek uygulamadan yedi gerçek isteği listeleyen Network sekmesi: bilinmeyen bir sunucuya yapılan başarısız bir istek, bir 503, bir 404 ve süre ile boyutlarıyla birlikte dört başarılı istek"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="Konsolda açılmış bir oturum açma isteği: Authorization header'ı ve JSON gövdesindeki parola [REDACTED] olarak görünüyor"></picture>
</p>

## Öne çıkanlar

- **Tek satırla kayıt** — `NetworkCapture.start()`, `URLSession.shared`'i ve bundan sonra varsayılan
  ya da ephemeral yapılandırmayla oluşturulan her oturumu kaydeder; `URLSession` üzerine kurulu
  kütüphaneler de buna dahildir. Uygulamanız her yanıtı değişmeden alır.
- **Saklamadan önce maskeleme** — gizli adlar (`password`, `token`, `api_key`; nasıl yazılmış ya
  da kodlanmış olursa olsun) ve düz ASCII olmayan anahtarlar altındaki değerler değiştirilir;
  değerini yalnızca izin listesindeki header'lar ve sorgu parametreleri korur. JSON, form ve
  multipart gövdeleri ayrıştırılır; ayrıştırılamayan bir gövde saklanmak yerine bir notla
  değiştirilir. Bir günlük mesajında ilk gizli addan ya da izin listesinde olmayan ilk anahtardan
  mesajın sonuna kadar her şey gizlenir.
- **Sınırlı saklama** — varsayılan olarak en fazla 500 istek ve her gövdenin 256 KiB'ı;
  günlük mesajları bir halka arabellekte tutulur, 4 MiB'ı aşan yüklemeler kopyalanmak yerine
  akış olarak işlenir. Başlıklar ve URL'ler kısaltılmadan saklanır.
- **Dışa aktarma** — her istek kabukta güvenle kullanılabilen bir `curl` komutu olarak, her istek
  listesi ise HTTP Archive (HAR 1.2) olarak.
- **Günlükler ve cihaz raporu** — `LogStore` seviyeli ve kategorili mesajları tutar, aynı zamanda
  bunları birleşik günlük sistemine (unified logging) yazar; `DeviceSnapshot` sürümü, işletim
  sistemini, modeli, bellek kullanımını, termal durumu ve bir debugger'ın bağlı olup olmadığını
  bildirir.
- **Test edilmiş** — macOS'ta 560, iOS simülatöründe 557 Swift Testing testi. İstekler bir uygulama
  oturumundan yakalama katmanı üzerinden bir stub sunucuya gider; testler sunucunun neyi aldığını,
  uygulamanın neyi aldığını ve neyin saklandığını kontrol eder.

## Hızlı başlangıç

**1. Paketi ekleyin**

Xcode'da **File › Add Package Dependencies…** menüsünü seçin ve depo adresini girin:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Pencerenin sağ üstündeki arama alanına yapıştırın. **Dependency Rule** ayarını `2.0.0` sürümünden
itibaren **Up to Next Major Version** olarak bırakın, ardından **Add Package**'a tıklayın.
Sonraki pencerede **iOSDevelopmentTools** yanındaki hedef olarak uygulamanızın target'ını seçin ve
yeniden **Add Package**'a tıklayın.

**2. Modülü içe aktarın**

```swift
import iOSDevelopmentTools
```

Bu satırı `App` yapınızı tanımlayan dosyanın en üstüne, `import SwiftUI` satırının altına ekleyin.

**3. Kaydı başlatın ve konsolu ekleyin**

Uygulamanızın `App` dosyasında yakalamayı `init` içinde başlatın ve konsolu kök görünüme ekleyin.
`#if DEBUG` satırları ikisini de release derlemelerinin dışında tutar:

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

Uygulamayı bir iPhone simülatöründe çalıştırın, bir istek yapmasını sağlayın ve Simulator
menüsünden **Device › Shake**'i seçin. Konsol, istek listede olacak şekilde Network sekmesinde açılır.

`devToolsConsoleOnShake()` yalnızca iOS'ta vardır. Uygulamanız macOS için de derleniyorsa onu
`#if DEBUG && os(iOS)` içine alın ve konsolu aşağıdaki **macOS'ta kullanın** bölümündeki gibi bir
pencerede açın.

## Kurulum

### Swift Package Manager

Xcode'da **File › Add Package Dependencies…** menüsünü seçin ve depo adresini girin:

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Ya da `Package.swift` dosyanızdaki `dependencies` listesine ekleyin:

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

## Kullanım

Aşağıdaki örnekler, örnek uygulamanın ve test paketinin derlediği
[ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift) dosyasından
kopyalanmıştır.

### Konsolu bir düğmeden açın

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### Kendi oluşturduğunuz bir oturumu kaydedin

`NetworkCapture.start()` çağrısından sonra `.default` veya `.ephemeral` ile oluşturulan oturumlar
otomatik olarak kaydedilir. Daha önce oluşturulmuş bir oturum için kaydı yapılandırmasına ekleyin:

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### Nelerin saklanacağını seçin

Aralık dışındaki sınırlar aralığa çekilir. Gizli adlar, karşılaştırıldıkları anahtarlar gibi
katlanır; bu yüzden `"license_number"` ifadesi `licenseNumber` ve `LICENSE-NUMBER` adlarını da
yakalar. Değerini yalnızca listelenen sorgu parametreleri korur:

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

### Neler kaydedilir

- **Kaydedilenler:** metot, durum kodu, zamanlamalar, header adları, izin listesindeki
  header'ların değerleri (varsayılan olarak `Accept`, `Accept-Encoding`, `Accept-Language`,
  `Cache-Control`, `Content-Encoding`, `Content-Length`, `Content-Type`, `ETag` ve `User-Agent`),
  URL'nin şeması, sunucusu, yolu ve sorgu parametresi adları; maskelendikten sonra JSON, form,
  multipart ve `text/plain` gövdeleri.
- **Asla kaydedilmeyenler:** URL'deki kullanıcı bilgisi ve fragment, izin listesinde olmayan sorgu
  değerleri, diğer bütün header'ların değerleri (`Authorization`, `Cookie` ve `Set-Cookie` izin
  listesinde olsa bile), `password`, `token` veya `api_key` gibi gizli adlar altındaki değerler,
  tanımlayıcıya benzeyen yol parçaları (`:id` olarak gösterilir) ve multipart gövdelerindeki dosya
  parçaları.
- **Düz ASCII olmayan anahtarların** değerleri varsayılan olarak gizlenir: kaçış dizileri
  çözüldükten, NFKC uygulandıktan ve harfler katlandıktan sonra ASCII dışı karakter içeren
  anahtarlar (Kiril `а` içeren `pаssword`, `pass\u200Dword`, `şifre`).
- **Ayrıştırılamayan gövdeler** (bilinmeyen ya da eksik içerik türü, bozuk JSON veya multipart,
  boyut sınırında kesilmiş bir gövde) `[body omitted: 512 bytes, application/xml]` gibi bir notla
  değiştirilir.
- **Günlük mesajları** ilk tetikleyiciye kadar tutulur: gizli bir ad, izin listesinde olmayan bir
  anahtar (varsayılan olarak `status`, `method`, `path`, `duration_ms` ve `count`; kendi
  anahtarlarınızı `allowedTextKeys` ile ekleyin), harf, işaret, rakam ya da boşluk olmayan ASCII
  dışı bir karakter (`꞉`, `…`, bir emoji), `%3D` gibi bir kaçış dizisi, izin verilmeyen tırnaklı bir
  anahtar (açılış tırnağından kesilir: `"x":"hunter2"`, `[REDACTED]` olarak saklanır), işaretleme
  (karşılaştırma olmayan bir `<`: `<b>`, `</x>`, `<!--`; hiçbir etiket metnini korumaz), kendi
  satırında kapanmayan bir tırnak, birbiriyle çakışan tırnaklar (`'x "y' z"`) ya da kapanmayan bir parantez, ondan sonraki her şeyi alttaki
  satırlarla birlikte gizler
  (`login password=hunter2 status=200`, `login password=[REDACTED]`; `x=hunter2` ise
  `x=[REDACTED]` olarak saklanır). Tetikleyici içermeyen bir mesaj, bulunan token'lar, kart
  numaraları ve e-posta adresleri dışında olduğu gibi tutulur.
- **Günlük mesajlarındaki URL'ler** için ada mantığı yoktur. Bir URL yalnızca temizse görünür
  kalır: `scheme://host` ve isteğe bağlı olarak ASCII harf, rakam, `.`, `_`, `-` ve `/`
  karakterlerinden oluşan bir yol; gizli bir ad olan bir host ya da yol parçası yok; ardından bir
  boşluk, satır sonu, metnin sonu ya da `.`, `,`, `!` ve `)` işaretlerinden yalnızca biri ve onun
  ardından bunlardan biri geliyor. Başka her URL (sorgu, fragment, port, kullanıcı bilgisi, `%3D`
  gibi bir kaçış dizisi, ardından gelen bir tırnak ya da iki işaret) mesajı URL'nin başladığı yerden
  itibaren gizler (`GET https://api.example.com/v1/items?page=2 done`, `GET [REDACTED]` olarak
  saklanır); `allowedQueryParameters` metindeki URL'lere değil, kaydedilen istek URL'lerine
  uygulanır.

Maskeleme bir güvenlik ağıdır, garanti değildir. Yanlışlıkla kaydedilen gizli bilgiler için
tasarlanmıştır: yapılandırılmış girdi ayrıştırılır ve ayrıştırıcının tam anlamadığı her şey
gizlenir; serbest metin ise en iyi çabadır ve `=` ya da `:` olmadan yazılmış, iki ya da daha fazla
harfi benzer görünen harflerle değiştirilmiş bir gizli adın (`pɑsswoʀd hunter2`) bulunacağı garanti
edilmez. Gizli bilgileri en baştan kaydettiğiniz isteklerin ve günlük mesajlarının dışında tutun ve
yapılandırılmış günlük kaydını tercih edin.

Bu modele iki sınır daha dahildir. **Maliyet sınırı:** bir girdinin içine gömülü bütün
belgeler (bir string içindeki JSON, metindeki bir URL) toplamda girdinin uzunluğunun en çok dört
katı kadar okunur; bu bütçe aşılınca sıradaki belgeyi taşıyan string bütünüyle gizlenir. **Çok
satırlı düzenler** özel bir işlem gerektirmez: kendi satırındaki bir property list `<key>`'i,
birden çok satıra yayılmış JSON ve metin olarak yazılmış bir multipart gövde ilk tetikleyiciden
metnin sonuna kadar gizlenir; böylece değer nereye yazılmış olursa olsun gizlenir.

### Mesajları günlüğe yazın

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### İstekleri ve raporları dışa aktarın

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

Konsolun paylaşım menüleri kullanıcı için aynısını yapar: Network sekmesinde **Export HAR**, bir
istekte **Share as cURL**, Device sekmesinde **Share Report**.

### macOS'ta kullanın

Mac uygulamasında sallama hareketi yoktur. Konsola kendi penceresini verin ve bir kısayolla açın:

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
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="Örnek uygulamadan info, warning ve error mesajlarını kategorisi, zamanı ve kaynak satırıyla gösteren Logs sekmesi"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="Uygulama sürümünü, iOS sürümünü, simüle edilen modeli, belleği, uygulamanın bellek kullanımını, termal durumu, Low Power Mode'u ve debugger durumunu gösteren Device sekmesi"></picture></td>
</tr>
</table>

Ekran görüntüleri, iOS 27 çalıştıran bir iPhone 17 Pro simülatöründe [örnek uygulamadan](Examples)
alınmış ve [`scripts/capture-screens.sh`](scripts/capture-screens.sh) ile yakalanmıştır. İstekler
gerçektir: uygulama bunları `api.github.com` ve `postman-echo.com` adreslerine gönderir. Çalıştırmak
için `Examples/DevToolsDemo/DevToolsDemo.xcodeproj` dosyasını açın, bir iPhone simülatörü ya da
**My Mac** seçin, uygulamayı çalıştırın ve **Send All**'a dokunun.

## Dokümantasyon

API başvuru belgeleri ve makaleler:

- [API başvurusu](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — parametreleri ve sınırlarıyla birlikte her public tür.

## Rehberler

- [Başlarken](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — paketi ekleyin, yakalamayı başlatın, konsolu açın, mesajları günlüğe yazın.
- [Ağ trafiğini yakalama](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — hangi oturumlar kaydedilir, istekler sunucuya nasıl ulaşır, bellek sınırları, nelerin kaydedilmediği.
- [Hassas verileri maskeleme](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — neler kaydedilir ve neler asla kaydedilmez, anahtarlar nasıl eşleştirilir, bazı gövdeler neden atlanır ve sınırlar.
- [Araçları release derlemelerinin dışında tutma](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — derleme koşulları ve ayrı bir dahili target.

## Gereksinimler

| Platform | En düşük sürüm |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| Araç zinciri | Swift 6.2 · Xcode 26+ |

Sallama hareketi yalnızca iOS'ta vardır; macOS'ta konsol bir pencerede ya da sheet olarak açılır.

## Mimari

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture`, bir `URLProtocol` olan `CaptureProtocol`'ü `URLSession.shared` için kaydeder ve
  varsayılan ile ephemeral yapılandırmalara ekler. Protokol her isteği tek bir dahili `URLSession`
  üzerinden iletir ve yüklemeyi başlatan thread'de uygulamanın oturumunu geri çağırır.
- `RedactionPolicy`, bir `NetworkEntry` oluşturulmadan önce çalışır; bu yüzden depolar ve dışa
  aktarmalar yalnızca maskelenmiş değerleri görür.
- `NetworkLogger` ve `LogStore`, değişiklikleri bir `AsyncStream` üzerinden yayımlayan, kilitle
  korunan halka arabelleklerdir; konsolun observable modelleri bunları saniyede en fazla yaklaşık
  yedi kez okur.
- Konsol görünümleri dışındaki her şey `Sendable`'dır ve herhangi bir thread'den çağrılabilir.

## Yol haritası

Planlananlar, belirli bir sıra olmadan: isteklerin uygulama açılışları arasında saklanması,
`LogStore` için bir `swift-log` backend'i, konsol için tvOS ve visionOS desteği ve istek taklidi
(mocking). Önerilerinizi [issue](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)
olarak paylaşabilirsiniz.

## Katkıda bulunma

Katkılarınızı bekliyoruz. Pull request açmadan önce [katkı rehberini](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md) ve [davranış kurallarını](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md) okuyun. Güvenlik açıklarını [güvenlik politikasında](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md) anlatıldığı gibi gizli olarak bildirin.

## Lisans

MIT lisansıyla yayımlanmıştır. Ayrıntılar için [LICENSE](LICENSE) dosyasına bakın.
