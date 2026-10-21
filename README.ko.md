<!-- i18n-source: README.md@35e61d77773f37038a6c7b618c6465a324f8f277 status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ko-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ko-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/banner-ko-light.svg" alt="iOSDevelopmentTools: 앱의 네트워크 요청, 로그, 기기 상태를 앱 내 콘솔에서 확인하세요. 민감한 정보는 가려집니다."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/iOSDevelopmentTools/actions/workflows/ci.yml/badge.svg" alt="CI 상태"></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-version-light.svg" alt="최신 버전: v2.1.0"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-platforms-light.svg" alt="지원 플랫폼: iOS 17+ · macOS 14+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-language-light.svg" alt="언어 버전: Swift 6.2+"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/badge-license-light.svg" alt="라이선스: MIT"></picture></a>
</p>

<p align="center">
<a href="#빠른-시작"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ko-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ko-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-start-ko-light.svg" alt="시작하기"></picture></a>
<a href="https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ko-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ko-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-docs-ko-light.svg" alt="문서"></picture></a>
<a href="https://github.com/muhittincamdali/iOSDevelopmentTools/tree/master/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ko-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ko-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/iOSDevelopmentTools/master/.github/brand/button-examples-ko-light.svg" alt="예제"></picture></a>
</p>

> 이 문서는 영어 README의 번역본입니다. 내용이 다를 경우 영어 버전이 최신입니다.

<!-- brand:end -->

iOS 또는 macOS 앱 안에 디버깅 콘솔을 넣어 주는 Swift 패키지입니다. 앱이 `URLSession`으로 보내는
요청을 기록하고, 로그 메시지를 보관하며, 기기 리포트를 수집한 뒤, 이 세 가지를 모두 SwiftUI 콘솔에
보여 줍니다. 콘솔은 흔들기, 버튼 또는 별도의 창으로 열 수 있습니다. 요청을 열면 헤더, 본문, 소요
시간을 볼 수 있고, cURL 명령으로 공유하거나 브라우저 개발자 도구, Charles, Proxyman에서 쓸 HAR 파일로
공유할 수도 있습니다. 비밀번호, 토큰, 쿠키, API 키는 저장되기 전에 다른 값으로 바뀌므로 콘솔, 내보낸
파일, 버그 리포트에 첨부한 스크린샷에 남지 않습니다. 디버그 및 테스트 빌드용이며, 의존성이 없고,
Swift 6 strict concurrency에 맞춰 작성되었습니다.

<p align="center">
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/network-dark.png"><img src="docs/images/network-light.png" width="300" alt="예제 앱의 실제 요청 7개를 보여 주는 Network 탭: 알 수 없는 호스트로 보낸 실패한 요청 하나, 503 하나, 404 하나, 그리고 소요 시간과 크기가 표시된 성공한 요청 네 개"></picture>
<picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/request-dark.png"><img src="docs/images/request-light.png" width="300" alt="콘솔에서 연 로그인 요청: Authorization 헤더와 JSON 본문의 비밀번호가 [REDACTED]로 표시됨"></picture>
</p>

## 주요 기능

- **한 줄로 기록 시작** — `NetworkCapture.start()`는 `URLSession.shared`와 이후에 default 또는
  ephemeral 구성으로 만들어지는 모든 세션을 기록합니다. `URLSession` 위에 만들어진 라이브러리도
  포함됩니다. 앱은 모든 응답을 변경 없이 그대로 받습니다.
- **저장 전에 가리기** — 비밀 이름(`password`, `token`, `api_key`, 철자나 인코딩과 상관없이)과
  순수 ASCII가 아닌 키 아래의 값은 바뀌고, 허용 목록에 있는 헤더와 쿼리 매개변수만 값을 유지합니다.
  JSON, 폼, multipart 본문은 파싱하며, 파싱할 수 없는 본문은 저장하는 대신 안내 문구로 바꿉니다.
  로그 메시지에서는 첫 번째 비밀 이름 또는 허용 목록에 없는 키부터 메시지 끝까지 모두
  가려집니다.
- **저장량 제한** — 기본값으로 요청은 최대 500개, 본문은 각각 최대 256 KiB입니다. 로그
  메시지는 링 버퍼에 보관하고, 4 MiB를 넘는 업로드는 복사하지 않고 스트리밍합니다.
  헤더와 URL은 자르지 않고 그대로 저장합니다.
- **내보내기** — 모든 요청을 셸에서 안전하게 쓸 수 있는 `curl` 명령으로, 모든 요청 목록을 HTTP
  Archive(HAR 1.2)로 내보낼 수 있습니다.
- **로그와 기기 리포트** — `LogStore`는 레벨과 카테고리가 있는 메시지를 보관하고 통합 로깅 시스템
  (unified logging)에도 기록합니다. `DeviceSnapshot`은 버전, OS, 모델, 메모리 사용량, 열 상태,
  디버거가 연결되어 있는지 여부를 보고합니다.
- **테스트 완료** — macOS에서 Swift Testing 테스트 631개, iOS 시뮬레이터에서 628개를 실행합니다.
  요청은 앱 세션에서 캡처 계층을 거쳐 스텁 서버로 전달되며, 테스트는 서버가 받은 것, 앱이 받은 것,
  저장된 것을 확인합니다.

## 빠른 시작

**1. 패키지 추가**

Xcode에서 **File › Add Package Dependencies…**를 선택하고 저장소 URL을 입력하세요.

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

창 오른쪽 위의 검색 필드에 붙여 넣으세요. **Dependency Rule**은 `2.1.0`부터 시작하는
**Up to Next Major Version**으로 둔 채 **Add Package**를 클릭합니다. 다음 창에서
**iOSDevelopmentTools** 옆에 있는 앱 타깃을 선택하고 **Add Package**를 다시 클릭하세요.

**2. 모듈 가져오기**

```swift
import iOSDevelopmentTools
```

이 줄은 `App`을 선언하는 파일의 맨 위, `import SwiftUI` 아래에 넣으세요.

**3. 기록을 시작하고 콘솔 추가하기**

앱의 `App` 파일에서 `init` 안에 캡처를 시작하고 루트 뷰에 콘솔을 추가하세요. `#if DEBUG` 줄 덕분에
둘 다 릴리스 빌드에는 들어가지 않습니다.

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

iPhone 시뮬레이터에서 앱을 실행해 요청을 한 번 보내게 한 다음, Simulator 메뉴에서
**Device › Shake**를 선택하세요. 콘솔이 Network 탭으로 열리고 목록에 그 요청이 표시됩니다.

`devToolsConsoleOnShake()`는 iOS에서만 사용할 수 있습니다. macOS용으로도 빌드하는 앱에서는 대신
`#if DEBUG && os(iOS)`로 감싸고, 아래 **macOS에서 사용하기**에서처럼 콘솔에 별도의 창을 제공하세요.

## 설치

### Swift Package Manager

Xcode에서 **File › Add Package Dependencies…**를 선택하고 저장소 URL을 입력하세요.

```text
https://github.com/muhittincamdali/iOSDevelopmentTools.git
```

또는 `Package.swift`의 `dependencies`에 추가하세요.

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

## 사용법

아래 예제는 [ReadmeSamples.swift](Examples/DevToolsDemo/DevToolsDemo/ReadmeSamples.swift)에서
복사한 것입니다. 이 파일은 예제 앱과 테스트 스위트에서 컴파일됩니다.

### 버튼으로 콘솔 열기

```swift
struct DebugMenuButton: View {
    @State private var showsTools = false

    var body: some View {
        Button("Developer Tools") { showsTools = true }
            .devToolsConsole(isPresented: $showsTools)
    }
}
```

### 직접 만든 세션 기록하기

`NetworkCapture.start()` 이후에 `.default` 또는 `.ephemeral`로 만든 세션은 자동으로 기록됩니다.
그보다 먼저 만든 세션에는 구성에 기록 기능을 추가하세요.

```swift
func makeAPISession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    NetworkCapture.install(into: configuration)
    return URLSession(configuration: configuration)
}
```

### 보관할 내용 선택하기

범위를 벗어난 한도 값은 범위 안으로 조정됩니다. 비밀 이름은 비교 대상인 키와 같은 방식으로
정규화되므로 `"license_number"`는 `licenseNumber`와 `LICENSE-NUMBER`도 잡아내며, 나열한 쿼리
매개변수만 값을 유지합니다.

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

### 기록되는 내용

- **기록되는 것:** 메서드, 상태 코드, 소요 시간, 헤더 이름, 허용 목록에 있는 헤더의 값(기본값은
  `Accept`, `Accept-Encoding`, `Accept-Language`, `Cache-Control`, `Content-Encoding`,
  `Content-Length`, `Content-Type`, `ETag`, `User-Agent`), URL의 스킴, 호스트, 경로, 쿼리 매개변수
  이름, 그리고 가린 뒤의 JSON, 폼, multipart, `text/plain` 본문.
- **절대 기록되지 않는 것:** URL의 사용자 정보와 프래그먼트, 허용 목록에 없는 쿼리 값, 그 밖의 모든
  헤더 값(`Authorization`, `Cookie`, `Set-Cookie`는 허용 목록에 있어도 제외), `password`, `token`,
  `api_key` 같은 비밀 이름 아래의 값, 식별자처럼 보이는 경로 세그먼트(`:id`로 표시), 비밀 이름이거나
  일반 ASCII가 아닌 세그먼트 다음의 세그먼트(`/caf%C3%A9/menu`는 `/caf%C3%A9/:id`로 기록), 점 세그먼트
  (`/pin/./4831`, `..`, `%2E`)나 `;`(`/cart;jsessionid=…`, `%3B`)가 있는 URL의 경로와 쿼리(스킴과 호스트만
  기록하며 매트릭스 파라미터는 해석하지 않음), 비밀 이름을 나타내는 호스트 뒤의 경로와 쿼리
  (`myapp://pin/4831`은 `myapp://pin`으로 기록하며, `auth.example.com` 같은 호스트도 경로를
  가림), multipart 본문의 파일 파트.
- **순수 ASCII가 아닌 키**(이스케이프를 풀고 NFKC를 적용하고 대소문자를 맞춘 뒤 기준, 예를 들어
  키릴 문자 `а`가 들어간 `pаssword`, `pass\u200Dword`, `şifre`)의 값은 기본적으로 가려집니다.
- **파싱할 수 없는 본문**(알 수 없거나 없는 Content-Type, 잘못된 JSON이나 multipart, 크기 한도에서
  잘린 본문)은 `[body omitted: 512 bytes, application/xml]` 같은 안내 문구로 바뀝니다.
- **로그 메시지**는 첫 번째 트리거까지만 보관됩니다. 비밀 이름, 허용 목록에 없는 키(기본값은
  `status`, `method`, `path`, `duration_ms`, `count`이며 `allowedTextKeys`로 직접 추가할 수
  있습니다), 문자·결합 부호·숫자·공백이 아닌 ASCII 밖의 문자(`꞉`, `…`, 이모지, 호환성 정규화가 문장 부호로
  읽는 문자. 예: `0,`으로 읽히는 `🄁`), 모든 형태의 이스케이프(공백이 아닌 문자 앞의 백슬래시, `%3D`,
  문자나 `#` 앞의 `&`: `R&D`, `&amp`), 허용되지 않은 따옴표 속 키(여는 따옴표에서 잘립니다. `"x":"hunter2"`는
  `[REDACTED]`로 저장됩니다), 마크업(비교가 아닌 `<`: `<b>`, `</x>`, `<!--`. 어떤 태그도 텍스트를
  남기지 않습니다), 같은 줄에서 닫히지 않은 따옴표, 서로 겹치는 따옴표(`'x "y' z"`), 닫히지 않은 괄호가 나오면 그 뒤의 모든 내용이
  아래 줄까지 가려집니다
  (`login password=hunter2 status=200`은 `login password=[REDACTED]`로, `x=hunter2`는
  `x=[REDACTED]`로 저장됩니다). 트리거가 없는 메시지는 감지된 토큰, 카드 번호, 이메일 주소를 빼고
  그대로 보관됩니다.
  감지기는 메시지를 자르는 VT, FF, U+0085, U+2028, U+2029를 건너 읽으므로, 이들로 나뉜
  카드 번호, IBAN, 이메일 주소, 토큰은 시작부터 가려집니다(`paid 4111 1111 1111`, U+2028,
  `1111`은 `paid [REDACTED]`로 저장됩니다). LF와 CR은 감지 대상을 끝냅니다.
- **로그 메시지 속 URL**에는 섬 논리가 없습니다. URL은 깨끗할 때만 그대로 보입니다. 즉
  `scheme://host`와 ASCII 문자, 숫자, `.`, `_`, `-`, `/`로만 된 선택적 경로로 이루어지고,
  비밀 이름인 호스트나 경로 세그먼트가 없으며, 바로 뒤에 공백, 줄 끝, 텍스트의 끝, 또는 `.`, `,`,
  `!`, `)` 중 하나와 그 뒤의 공백·줄 끝·텍스트의 끝이 와야 합니다. 그 밖의 URL(쿼리, 프래그먼트,
  포트, 사용자 정보, `%3D` 같은 이스케이프가 있거나 뒤에 따옴표나 문장 부호 두 개가 오는 URL)은 URL이 시작하는 곳부터 메시지를 가립니다
  (`GET https://api.example.com/v1/items?page=2 done`은 `GET [REDACTED]`로 저장됩니다).
  `allowedQueryParameters`는 기록된 요청 URL에 적용되며 텍스트 속 URL에는 적용되지 않습니다.

가리기는 안전망일 뿐 보장이 아닙니다. 실수로 기록된 비밀 값을 위해 만들어졌습니다. 구조화된 입력은
파싱하고, 파서가 완전히 이해하지 못하는 부분은 가립니다. 자유 형식 텍스트는 최선의 노력일 뿐이며,
`=`나 `:` 없이 쓰고 두 글자 이상을 비슷하게 생긴 글자로 바꾼 비밀 이름(`pɑsswoʀd hunter2`)은
찾는다고 보장할 수 없습니다. ASCII 형태가 없는 글자, 결합 문자, 숫자 하나는 아무 글자로 읽으므로
`tͦken hunter2`, `passw〇rd hunter2`, `t၀ken hunter2`(미얀마 숫자 0)는 찾습니다. 애초에 기록하는 요청과 로그 메시지에 비밀 값을 넣지 말고, 구조화된
로깅을 쓰세요.

이 모델에는 두 가지 한계가 더 있습니다. **비용 상한:** 한 입력 안에 중첩된 모든 문서(문자열 속
JSON, 텍스트 속 URL)는 합쳐서 입력 길이의 최대 4배까지만 읽습니다. 이 예산을 넘으면 다음 문서를
담은 문자열 전체를 가립니다. **여러 줄 레이아웃**에는 특별한 처리가 필요 없습니다. 한 줄에
따로 쓴 property list `<key>`, 여러 줄에 걸친 JSON, 텍스트로 쓴 multipart 본문은 첫 번째
트리거부터 텍스트 끝까지 가려지므로 값이 어디에 쓰였든 가려집니다.

### 메시지 로그 남기기

```swift
func logCheckout(orderID: String, error: (any Error)?) {
    if let error {
        LogStore.shared.error("Order \(orderID) failed: \(error.localizedDescription)", category: "checkout")
    } else {
        LogStore.shared.info("Order \(orderID) placed", category: "checkout")
    }
}
```

### 요청과 리포트 내보내기

```swift
func exportForBugReport() throws -> (har: Data, curl: [String], device: String) {
    let entries = NetworkLogger.shared.entries
    let har = try HTTPArchive(entries: entries).jsonData()
    let curl = entries.map { $0.curlCommand() }
    let device = DeviceSnapshot.current().report()
    return (har, curl, device)
}
```

콘솔의 공유 메뉴도 사용자를 위해 같은 일을 합니다. Network 탭의 **Export HAR**, 요청 화면의
**Share as cURL**, Device 탭의 **Share Report**입니다.

### macOS에서 사용하기

Mac 앱에는 흔들기가 없습니다. 콘솔에 전용 창을 주고 단축키로 여세요.

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

## 데모

<table>
<tr>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/logs-dark.png"><img src="docs/images/logs-light.png" width="260" alt="예제 앱의 info, warning, error 메시지를 카테고리, 시간, 소스 라인과 함께 보여 주는 Logs 탭"></picture></td>
<td><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/device-dark.png"><img src="docs/images/device-light.png" width="260" alt="앱 버전, iOS 버전, 시뮬레이션된 모델, 메모리, 앱 메모리, 열 상태, Low Power Mode, 디버거 상태를 보여 주는 Device 탭"></picture></td>
</tr>
</table>

스크린샷은 iOS 27이 설치된 iPhone 17 Pro 시뮬레이터에서 [예제 앱](Examples)을 실행하고
[`scripts/capture-screens.sh`](scripts/capture-screens.sh)로 캡처한 것입니다. 요청은 실제 요청이며,
앱이 `api.github.com`과 `postman-echo.com`으로 보냅니다. 실행하려면
`Examples/DevToolsDemo/DevToolsDemo.xcodeproj`를 열고 iPhone 시뮬레이터나 **My Mac**을 선택해 실행한
다음 **Send All**을 탭하세요.

## 문서

API 레퍼런스와 문서:

- [API 레퍼런스](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/)
  — 모든 공개 타입을 매개변수와 제한 사항과 함께 설명합니다.

## 가이드

- [시작하기](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/gettingstarted)
  — 패키지 추가, 캡처 시작, 콘솔 열기, 메시지 로그 남기기.
- [네트워크 트래픽 캡처하기](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/capturingnetworktraffic)
  — 기록되는 세션, 요청이 서버에 도달하는 방식, 메모리 한도, 기록되지 않는 것.
- [민감한 데이터 가리기](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/redactingsensitivedata)
  — 기록되는 것과 절대 기록되지 않는 것, 키를 비교하는 방식, 일부 본문을 생략하는 이유, 그리고 한계.
- [릴리스 빌드에서 도구 제외하기](https://muhittincamdali.github.io/iOSDevelopmentTools/documentation/iosdevelopmenttools/keepingtoolsoutofreleasebuilds)
  — 컴파일 조건과 별도의 내부용 타깃.

## 요구 사항

| 플랫폼 | 최소 버전 |
| ------------------- | ------------------ |
| iOS | 17 |
| macOS | 14 |
| 툴체인 | Swift 6.2 · Xcode 26+ |

흔들기 제스처는 iOS에서만 지원됩니다. macOS에서는 콘솔이 창이나 시트로 열립니다.

## 아키텍처

```text
URLSession ──► CaptureProtocol ──► ForwardingSession ──► server
 (your app)      │  redacts a copy        │
                 ▼                        ▼  response, unchanged, back to your app
            NetworkLogger ◄──────── status, body prefix, metrics
                 │
LogStore ────────┼──► DevToolsConsole (Network · Logs · Device tabs)
DeviceSnapshot ──┘
```

- `NetworkCapture`는 `URLProtocol`인 `CaptureProtocol`을 `URLSession.shared`에 등록하고 default 및
  ephemeral 구성에 추가합니다. 이 프로토콜은 각 요청을 내부 `URLSession` 하나를 통해 전달하고,
  로드를 시작한 스레드에서 앱의 세션을 다시 호출합니다.
- `RedactionPolicy`는 `NetworkEntry`가 만들어지기 전에 실행되므로, 저장소와 내보내기에는 가려진
  값만 전달됩니다.
- `NetworkLogger`와 `LogStore`는 잠금으로 보호되는 링 버퍼로, 변경 사항을 `AsyncStream`으로
  발행합니다. 콘솔의 observable 모델은 이를 초당 최대 7번 정도만 읽습니다.
- 콘솔 뷰를 제외한 모든 것은 `Sendable`이며 어떤 스레드에서든 호출할 수 있습니다.

## 로드맵

순서 없이 계획 중인 항목: 앱을 다시 실행해도 요청 유지하기, `LogStore`용 `swift-log` 백엔드,
콘솔의 tvOS 및 visionOS 지원, 요청 모킹. 제안은
[issues](https://github.com/muhittincamdali/iOSDevelopmentTools/issues)에 남겨 주세요.

## 기여하기

기여를 환영합니다. pull request를 열기 전에 [기여 가이드](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/CONTRIBUTING.md)와 [행동 강령](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md)을 읽어 주세요. 보안 문제는 [보안 정책](https://github.com/muhittincamdali/iOSDevelopmentTools/blob/master/SECURITY.md)에 따라 비공개로 제보해 주세요.

## 라이선스

MIT 라이선스로 배포됩니다. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
