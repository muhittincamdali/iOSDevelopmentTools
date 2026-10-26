import Foundation
import Testing
@testable import iOSDevelopmentTools

/// One letter that has no ASCII form, put in before the last letter of a short secret word. The
/// sixth review of the spec branch found that the match read that letter as the word's last one,
/// ended a letter early and failed the word's placement (`tokeꞏn` read as `toke?` before `n`),
/// without trying it as no letter. Fourteen of sixteen short words were not found, in free text
/// and in the URL segments, record names and allowed values that read names in it.
@Suite("Redaction corpus: a wildcard before the last letter")
struct RedactionWildcardPlacementTests {
    static let secret = "Yk002Wq7z"

    static let words = [
        "tokeꞏn", "secreꞏt", "piꞏn", "keꞏy", "otꞏp", "cvꞏv", "cvꞏc", "autꞏh", "carꞏd", "ibaꞏn", "pwꞏd", "siꞏd", "pꞏw",
        "tokeın", "piøn", "keły", "otŋp", "cvɛv", "autðh", "pwød", "keıy", "piın",
    ]

    @Test("the word is found in every place free text is read", arguments: words)
    func freeText(word: String) {
        let line = "\(word) \(Self.secret)"
        var outputs = RedactionWrittenURLTests.places(line)
        let header = RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: "MyApp/1.0 " + line)])[0].value
        outputs.append(("User-Agent", header))
        for (place, output) in outputs {
            #expect(!output.contains(Self.secret), "\(place): \(line.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("the word is found as a URL segment, a record name and an allowed query value", arguments: ["tokeꞏn", "piın", "secreꞏt", "keıy"])
    func structured(word: String) {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let redactor = Redactor(allowedQueryParameters: ["q"])
        var outputs = [
            redactor.redact(url: URL(string: "https://x.example/v1/\(encoded)/\(Self.secret)")!),
            redactor.redact(url: URL(string: "https://x.example/a?q=\(encoded)+\(Self.secret)")!),
        ]
        for json in [#"{"name":"\#(word)","note":"\#(Self.secret)"}"#, #"{"type":"\#(word)","default":"\#(Self.secret)"}"#,
                     #"[{"id":"\#(word)","current":"\#(Self.secret)"}]"#] {
            outputs.append(redactor.redact(body: Data(json.utf8), contentType: "application/json"))
        }
        outputs.append(redactor.redact(body: Data("name=\(encoded)&note=\(Self.secret)".utf8), contentType: "application/x-www-form-urlencoded"))
        let multipart = "--B\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\n\(word)\r\n"
            + "--B\r\nContent-Disposition: form-data; name=\"other\"\r\n\r\n\(Self.secret)\r\n--B--\r\n"
        outputs.append(redactor.redact(body: Data(multipart.utf8), contentType: "multipart/form-data; boundary=B"))
        for output in outputs {
            #expect(!output.contains(Self.secret), "\(word) -> \(output.debugDescription)")
        }
    }

    @Test("ordinary words that end in a letter without an ASCII form after a short word stay readable", arguments: [
        "Kullanıcı sisteme başarıyla giriş yaptı", "bjørn dæhlie kom hjem", "Øresund bridge", "çay içtik", "kapıdaki ılgın ağaçları",
    ])
    func ordinaryWords(line: String) {
        #expect(Redactor().redact(line) == line)
    }
}
