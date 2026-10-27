<!-- i18n-source: README.md@6a2fd145c01be99a7a207f7e8a45812f5f3761ef status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-fr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-fr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-fr-light.svg" alt="iOSDevelopmentTools: Requêtes réseau, journaux et état de l'appareil de votre app dans une console intégrée, secrets masqués."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="État de la CI"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="Dernière version: v2.1.1"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="Plateformes prises en charge: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="Version du langage: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="Licence: MIT"></picture></a>
</p>

<p align="center">
<a href="#démarrage-rapide"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-fr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-fr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-fr-light.svg" alt="Commencer"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-fr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-fr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-fr-light.svg" alt="Documentation"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-fr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-fr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-fr-light.svg" alt="Exemples"></picture></a>
</p>

> Ceci est une traduction du README anglais. En cas de différence, la version anglaise fait foi.

<!-- brand:end -->

Un paquet Swift qui place une console de débogage dans votre app iOS ou macOS. Il enregistre les
requêtes que votre app envoie avec `URLSession`, conserve vos messages de journal et collecte un rapport
sur l'appareil, puis affiche les trois dans une console SwiftUI qui s'ouvre en secouant l'appareil, avec
un bouton ou dans une fenêtre. Ouvrez une requête pour voir ses en-têtes, ses corps et ses durées, ou
partagez-la sous forme de commande cURL ou de fichier HAR pour les outils de développement du
navigateur, Charles ou Proxyman. Les mots de passe, les jetons, les cookies et les clés d'API sont
remplacés avant tout stockage : ils n'apparaissent donc ni dans la console, ni dans un fichier exporté,
ni dans une capture d'écran jointe à un rapport de bug. Il est conçu pour les builds de debug et de test,
n'a aucune dépendance et est écrit pour la strict concurrency de Swift 6.

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="L'onglet Network listant sept requêtes réelles de l'app d'exemple : une requête échouée vers un hôte inconnu, un 503, un 404 et quatre requêtes réussies avec leur durée et leur taille"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="Une requête de connexion ouverte dans la console : l'en-tête Authorization et le mot de passe du corps JSON affichent [REDACTED]"></picture>
</p>

## Points forts

- **Une ligne pour enregistrer** — `NetworkCapture.start()` enregistre `URLSession.shared` ainsi que
  toutes les sessions créées ensuite à partir de la configuration default ou ephemeral, y compris celles
  des bibliothèques construites sur `URLSession`. Votre app reçoit chaque réponse sans modification.
- **Masquage avant stockage** — les valeurs placées sous des noms secrets (`password`, `token`,
  `api_key`, quelle que soit leur écriture ou leur encodage) et sous des clés qui ne sont pas en
  ASCII simple sont remplacées, et seuls les en-têtes et paramètres de query de la liste autorisée
  gardent leur valeur. Les corps JSON, de formulaire et multipart sont analysés ; un corps
  impossible à analyser est remplacé par une note au lieu d'être stocké. Dans un message de
  journal, tout est masqué du premier nom secret, ou de la première clé absente de la liste
  autorisée, jusqu'à la fin.
- **Stockage borné** — par défaut, au plus 500 requêtes et 256 KiB par corps ; les messages de journal
  sont conservés dans un tampon circulaire, et les envois de plus de 4 MiB sont transmis en flux au lieu
  d'être copiés. Les en-têtes et les URL sont stockés en entier.
- **Export** — n'importe quelle requête sous forme de commande `curl` sûre pour le shell, n'importe
  quelle liste de requêtes sous forme de HTTP Archive (HAR 1.2).
- **Journaux et rapport sur l'appareil** — `LogStore` conserve des messages avec niveau et catégorie et
  les écrit aussi dans le système de journalisation unifié (unified logging) ; `DeviceSnapshot`
  indique la version, l'OS, le modèle, l'empreinte mémoire, l'état thermique et si un débogueur est
  attaché.
- **Testé** — 880 tests Swift Testing sur macOS et 877 sur un simulateur iOS. Les requêtes passent d'une
  session de l'app à un serveur stub via la capture, et les tests vérifient ce que le serveur a reçu,
  ce que l'app a reçu et ce qui a été stocké.

## Démarrage rapide

**1. Ajouter le paquet**

Dans Xcode, choisissez **File › Add Package Dependencies…** et saisissez l’URL du dépôt :

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Collez-la dans le champ de recherche en haut à droite de la fenêtre. Laissez **Dependency Rule** sur
**Up to Next Major Version** à partir de `2.1.2`, puis cliquez sur **Add Package**. Dans la fenêtre
suivante, choisissez le target de votre app à côté de **iOSDevelopmentTools** et cliquez de nouveau sur
**Add Package**.

**2. Importer le module**

```swift
import iOSDevelopmentTools
```

Placez cette ligne en haut du fichier qui déclare votre `App`, sous `import SwiftUI`.

**3. Démarrer l'enregistrement et ajouter la console**

Dans le fichier `App` de votre app, démarrez la capture dans `init` et ajoutez la console à la vue
racine. Les lignes `#if DEBUG` laissent les deux hors des builds de release :

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

Lancez l'app dans un simulateur d'iPhone, faites-lui envoyer une requête, puis choisissez
**Device › Shake** dans le menu de Simulator. La console s'ouvre sur l'onglet Network avec la requête
dans la liste.

`devToolsConsoleOnShake()` n'existe que sur iOS. Si votre app est aussi compilée pour macOS,
entourez-le plutôt de `#if DEBUG && os(iOS)` et ouvrez la console dans une fenêtre, comme dans
**L'utiliser sur macOS** plus bas.

## Installation

### Swift Package Manager

Dans Xcode, choisissez **File › Add Package Dependencies…** et saisissez l’URL du dépôt :

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

Ou ajoutez-le aux `dependencies` de votre `Package.swift` :

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOSDevelopmentTools.git", from: "2.1.2")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "iOSDevelopmentTools", package: "iOSDevelopmentTools")
    ])
]
```

## Utilisation

Les exemples ci-dessous sont copiés depuis
[ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift), que l'app d'exemple et
la suite de tests compilent.

### Ouvrir la console depuis un bouton

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### Enregistrer une session que vous créez vous-même

Les sessions créées avec `.default` ou `.ephemeral` après `NetworkCapture.start()` sont enregistrées
automatiquement. Pour une session créée plus tôt, ajoutez l'enregistrement à sa configuration :

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### Choisir ce qui est conservé

Les limites hors plage sont ramenées dans la plage. Les noms secrets sont normalisés comme les clés
auxquelles ils sont comparés : `"license_number"` détecte donc aussi `licenseNumber` et
`LICENSE-NUMBER`, et seuls les paramètres de query indiqués gardent leur valeur :

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

### Ce qui est enregistré

- **Enregistré :** la méthode, le statut, les durées, les noms des en-têtes, les valeurs des
  en-têtes de la liste autorisée (par défaut `Accept`, `Accept-Encoding`, `Accept-Language`,
  `Cache-Control`, `Content-Encoding`, `Content-Length`, `Content-Type`, `ETag` et `User-Agent`),
  le schéma, l'hôte, le chemin et les noms des paramètres de query de l'URL, ainsi que les corps
  JSON, de formulaire, multipart et `text/plain` après masquage.
- **Jamais enregistré :** les informations utilisateur et le fragment de l'URL, les valeurs de
  query hors de la liste autorisée, les valeurs de tous les autres en-têtes (`Authorization`,
  `Cookie` et `Set-Cookie` même s'ils sont dans la liste), les valeurs placées sous des noms
  secrets comme `password`, `token` ou `api_key`, les segments de chemin qui ressemblent à des
  identifiants (affichés `:id`) et le segment qui suit un segment qui nomme un secret ou qui
  n'est pas en ASCII simple (`/caf%C3%A9/menu` est gardé comme `/caf%C3%A9/:id`), le chemin et la query d'une URL dont le chemin a un segment point
  (`/pin/./4831`, `..`, `/cart;jsessionid=…`), un `;` ou un `.`, `/`, `\`, `;` ou `%` échappé
  (`%2E`, `%2F`, `%5C`, `%3B`, `%25`) : seuls le schéma et l'hôte sont gardés, les paramètres
  matriciels ne sont donc jamais lus ; un hôte qui nomme un secret avec tout ce qui le suit
  (`myapp://pin/4831` et `myapp://pin-4831` sont gardés comme `myapp://[REDACTED]` ; un hôte comme
  `auth.example.com` est aussi masqué) ; les parties fichier des corps multipart ; et les valeurs des
  en-têtes de partie multipart autres que `Content-Length` et `Content-Transfer-Encoding`
  (`Content-ID` et quatre autres noms `Content-*` gardent leur nom ; tout autre en-tête
  de partie, comme `User-Agent`, est enregistré comme `[REDACTED]: [REDACTED]`), et toute valeur
  de ces deux-là hors de leur forme : un `Content-Length` qui n'est pas fait de chiffres ASCII et
  un `Content-Transfer-Encoding` autre que `7bit`, `8bit`, `binary`, `base64` ou
  `quoted-printable` (gardé en minuscules) sont enregistrés comme `[REDACTED]`
  (`Content-Length: pin-4831` comme `Content-Length: [REDACTED]`).
- **Les clés qui ne sont pas en ASCII simple** une fois les échappements décodés, NFKC appliqué et
  la casse normalisée (`pаssword` avec un `а` cyrillique, `pass\u200Dword`, `şifre`) ont leur
  valeur masquée par défaut.
- **Les corps impossibles à analyser** (un type de contenu inconnu ou absent, du JSON ou du
  multipart mal formé, un corps coupé à la limite de taille) sont remplacés par une note comme
  `[body omitted: 512 bytes, application/xml]`. Le type de la note, comme celui d'une partie
  multipart, est lu comme son en-tête : un type dans lequel la règle des en-têtes trouve quelque
  chose est écrit `[REDACTED]` (`application/4111111111111111` donne `[body omitted: 5 bytes, [REDACTED]]`).
- **Les messages de journal** sont conservés jusqu'à leur premier déclencheur : un nom secret, une
  clé absente de la liste autorisée (`status`, `method`, `path`, `duration_ms` et `count` par
  défaut ; ajoutez les vôtres avec `allowedTextKeys`), un caractère hors ASCII qui n'est ni une
  lettre, ni un signe diacritique, ni un chiffre (`꞉`, `…`, un emoji, une espace comme U+00A0, ou
  une lettre que la normalisation de compatibilité lit comme une ponctuation, comme `🄁`, lu `0,`),
  un mot qui mêle des écritures (`tоken` avec un `о` cyrillique), une séquence d'échappement de
  toute forme, coupée au début de son mot (une barre oblique inverse devant tout sauf un blanc,
  `%3D`, un `&` devant une lettre ou `#` : `R&D`, `&amp` ; un `&` qui commence un champ, comme
  dans `status=200&count=3`, n'en est pas une), une clé entre guillemets qui n'est pas autorisée (coupée à son
  guillemet ouvrant : `"x":"hunter2"` est stocké sous la forme `[REDACTED]`), du balisage (un
  `<` qui n'est pas une comparaison : `<b>`, `</x>`, `<!--` ; aucune balise ne garde son texte),
  un guillemet qui ne se ferme pas sur sa ligne, des guillemets qui se chevauchent
  (`'x "y' z"`) ou une parenthèse qui ne se ferme pas masque tout
  ce qui suit, y compris les lignes suivantes (`login password=hunter2 status=200` est stocké sous la
  forme `login password=[REDACTED]`, et `x=hunter2` sous la forme `x=[REDACTED]`). Un message sans
  déclencheur est conservé tel quel, hormis les jetons, numéros de carte et adresses e-mail
  détectés.
  Les détecteurs lisent à travers VT, FF, U+0085, U+2028 et U+2029, qui coupent le message : un
  numéro de carte, un IBAN, une adresse e-mail ou un jeton coupé par l'un d'eux est masqué depuis
  son début (`paid 4111 1111 1111`, U+2028, `1111` est enregistré sous la forme
  `paid [REDACTED]`) ; LF et CR terminent une détection.
- **Les URL dans les messages de log** n'ont pas de logique d'îlot. Une URL ne reste visible que si
  elle est propre : `scheme://host` avec un chemin facultatif fait de lettres ASCII, de chiffres,
  de `.`, `_`, `-` et `/`, sans hôte ni segment de chemin qui soit un nom secret, suivie d'une
  espace, d'une fin de ligne, de la fin du texte ou d'un seul `.`, `,`, `!` ou `)` suivi de l'un
  d'eux. Toute autre URL (une query, un fragment, un port, des informations d'utilisateur, un
  échappement comme `%3D`, un guillemet ou deux signes après elle) masque le message à partir du début de l'URL (`GET https://api.example.com/v1/items?page=2 done` est
  enregistré comme `GET [REDACTED]`) ; `allowedQueryParameters` s'applique aux URL des requêtes
  enregistrées, pas aux URL dans un texte.

Le masquage est un filet de sécurité, pas une garantie. Il est conçu pour les secrets enregistrés
par accident : les entrées structurées sont analysées, et ce que l'analyseur ne comprend pas
entièrement est masqué ; le texte libre est traité au mieux, et un nom secret écrit sans `=` ni `:`
dont deux lettres ou plus sont remplacées par des lettres qui se ressemblent (`pɑsswoʀd hunter2`)
n'est pas forcément trouvé ; une seule lettre, marque ou chiffre sans forme ASCII compte comme
n'importe quelle lettre, donc `tͦken hunter2`, `passw〇rd hunter2` et `t၀ken hunter2` (un zéro birman) sont trouvés. Gardez les secrets hors des requêtes que vous enregistrez et des
messages de journal dès le départ, et préférez une journalisation structurée.

Trois autres limites font partie de ce modèle. **Borne de coût :** tous les documents imbriqués
dans une même entrée (du JSON dans une chaîne, une URL dans un texte) lisent ensemble au plus quatre
fois la longueur de l'entrée ; au-delà de ce budget, la chaîne qui contient le document suivant est
masquée entièrement. **Borne de longueur :** un texte de plus de 2^28 − 1 scalaires Unicode
(268 435 455) n'est pas lu et est masqué entièrement. **Les mises en page sur plusieurs lignes** ne demandent rien de particulier :
un `<key>` de property list sur sa propre ligne, du JSON réparti sur plusieurs lignes et un corps
multipart écrit comme du texte sont masqués du premier déclencheur jusqu'à la fin du texte, si bien
que la valeur est masquée où qu'elle soit écrite.

### Journaliser des messages

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### Exporter des requêtes et des rapports

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

Les menus de partage de la console font la même chose pour l'utilisateur : **Export HAR** dans l'onglet
Network, **Share as cURL** dans une requête et **Share Report** dans l'onglet Device.

### L'utiliser sur macOS

Une app Mac n'a pas de geste de secousse. Donnez à la console sa propre fenêtre et ouvrez-la avec un
raccourci :

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

## Démo

<table>
<tr>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="L'onglet Logs avec des messages info, warning et error de l'app d'exemple, chacun avec sa catégorie, son heure et sa ligne source"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="L'onglet Device affichant la version de l'app, la version d'iOS, le modèle simulé, la mémoire, la mémoire de l'app, l'état thermique, le Low Power Mode et l'état du débogueur"></picture></td>
</tr>
</table>

Les captures d'écran viennent de l'[app d'exemple](Examples) sur un simulateur d'iPhone 17 Pro sous
iOS 27, réalisées avec [`scripts/capture-screens.sh`](scripts/capture-screens.sh). Les requêtes sont
réelles : l'app les envoie à `api.github.com` et à `postman-echo.com`. Pour la lancer, ouvrez
`Examples/DevToolsDemo/DevToolsDemo.xcodeproj`, choisissez un simulateur d'iPhone ou **My Mac**,
lancez l'app et touchez **Send All**.

## Documentation

Référence de l’API et articles :

- [Référence de l'API](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — chaque type public avec ses paramètres et ses limites.

## Guides

- [Premiers pas](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — ajouter le paquet, démarrer la capture, ouvrir la console, journaliser des messages.
- [Capturer le trafic réseau](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — quelles sessions sont enregistrées, comment les requêtes atteignent le serveur, limites de mémoire et ce qui n'est pas enregistré.
- [Masquer les données sensibles](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — ce qui est enregistré et ce qui ne l'est jamais, comment les clés sont comparées, pourquoi certains corps sont omis, et les limites.
- [Garder les outils hors des builds de release](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — conditions de compilation et un target interne distinct.

## Prérequis

| Plateforme | Version minimale |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| Chaîne d’outils | Swift 6.2 · Xcode 26+ |

Le geste de secousse n'existe que sous iOS ; sous macOS, la console s'ouvre dans une fenêtre ou une
sheet.

## Architecture

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture` enregistre `CaptureProtocol`, un `URLProtocol`, pour `URLSession.shared` et l'ajoute
  aux configurations default et ephemeral. Le protocole transmet chaque requête via une `URLSession`
  interne et rappelle la session de l'app sur le thread qui a démarré le chargement.
- `RedactionPolicy` s'exécute avant la création d'un `NetworkEntry`, si bien que les stockages et les
  exports ne voient que des valeurs masquées.
- `NetworkLogger` et `LogStore` sont des tampons circulaires protégés par verrou qui publient les
  changements via un `AsyncStream` ; les modèles observables de la console les lisent au plus environ
  sept fois par seconde.
- Tout ce qui est en dehors des vues de la console est `Sendable` et peut être appelé depuis n'importe
  quel thread.

## Feuille de route

Prévu, sans ordre fixe : conserver les requêtes d'un lancement à l'autre, un backend `swift-log` pour
`LogStore`, la prise en charge de tvOS et de visionOS par la console, et le mocking de requêtes. Les
suggestions sont les bienvenues dans les [issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues).

## Contribuer

Les contributions sont les bienvenues. Lisez le [guide de contribution](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md) et le [code de conduite](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md) avant d’ouvrir une pull request. Signalez les problèmes de sécurité en privé, comme indiqué dans la [politique de sécurité](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md).

## Licence

Publié sous licence MIT. Voir [LICENSE](LICENSE).
