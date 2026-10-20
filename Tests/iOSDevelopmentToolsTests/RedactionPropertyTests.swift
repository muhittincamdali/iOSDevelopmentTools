import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Generated obfuscations of every secret name and generated secrets must never be stored, and
/// ordinary keys, values and headers must be kept.
@Suite("Redaction: properties and usefulness")
struct RedactionPropertyTests {
    let policy = RedactionPolicy.default

    // MARK: Property: obfuscated secret names

    @Test("No generated obfuscation of a secret name lets its value through", arguments: RedactionPolicy.defaultSecretNames)
    func obfuscatedNames(name: String) throws {
        var generator = Obfuscator(seed: Obfuscator.seed(for: name))
        for round in 0..<Obfuscator.rounds {
            let (key, isFreeTextSafe) = generator.obfuscate(name)
            let secret = generator.secret()
            #expect(policy.isSensitive(name: key), "\(key.debugDescription) from \(name), round \(round)")
            for stored in try structuredRecords(key: key, secret: secret) {
                #expect(!stored.contains(secret), "\(key.debugDescription) stored \(stored.debugDescription)")
            }
            guard isFreeTextSafe else { continue }
            for line in ["\(key)=\(secret)", "x \(key): \(secret) y", "{\"\(key)\":\"\(secret)\",\"n\":1}"] {
                #expect(!policy.redact(text: line).contains(secret), "\(line.debugDescription)")
            }
        }
    }

    /// What is stored for the key and secret as a JSON field, a nested JSON field, a form field,
    /// an allowed query parameter, an allowed header and a multipart field.
    private func structuredRecords(key: String, secret: String) throws -> [String] {
        func body(_ data: Data, _ contentType: String) -> String {
            String(decoding: policy.redact(body: data, contentType: contentType).body, as: UTF8.self)
        }
        let encodedKey = percentEncodedASCII(key)
        let escapedKey = key.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let allowing = RedactionPolicy(allowedHeaders: [key], allowedQueryParameters: [key])
        let url = try #require(URL(string: "https://e.com/a?\(encodedKey)=\(secret)"))
        return [
            body(try JSONSerialization.data(withJSONObject: [key: secret, "page": 2]), "application/json"),
            body(try JSONSerialization.data(withJSONObject: ["a": [[key: [secret]]]]), "application/json"),
            body(Data("page=2&\(encodedKey)=\(secret)".utf8), "application/x-www-form-urlencoded"),
            allowing.redact(url: url),
            allowing.redact(headers: [HTTPHeader(name: key, value: secret)]).map(\.value).joined(),
            body(Data("--B\r\nContent-Disposition: form-data; name=\"\(escapedKey)\"\r\n\r\n\(secret)\r\n--B--\r\n".utf8), "multipart/form-data; boundary=B"),
        ]
    }

    // MARK: Property: random keys in free text

    /// Free-text lines that pair the key with the value in every shape the free-text rule reads.
    private func freeTextLines(key: String, value: String) throws -> [String] {
        func json(_ object: Any) throws -> String {
            String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        }
        return [
            "\(key)=\(value)", "\(key): \(value)", "\(key) = \(value)", "x \(key)=\"\(value) y\" z", "\(key)='\(value)' z",
            "\"\(key)\":\"\(value)\"", "status=200 \(key)=\(value) count=1", "\(key)=\(value)&status=1", "\(key):\n  \(value)",
            "\(key)\n= \(value)", "\(key)\u{2028}: \(value)", "log " + (try json([key: value])) + " done",
            try json(["status": 200, key: ["x": value]] as [String: Any]), try json([[key: [value]]]),
        ]
    }

    @Test("No value under a random key that is not plain ASCII or names a secret is stored from free text")
    func randomKeysInFreeText() throws {
        var generator = Obfuscator(seed: 6)
        var checked = 0
        while checked < 1_500 {
            let key = generator.randomKey()
            guard policy.isSensitive(name: key) else { continue }
            let value = generator.secret()
            for line in try freeTextLines(key: key, value: value) {
                let stored = policy.redact(text: line)
                #expect(!stored.contains(value), "\(line.debugDescription) stored \(stored.debugDescription)")
            }
            checked += 1
        }
    }

    @Test("Allowed keys stay readable in free text; other plain keys hide their value unless the app allows them")
    func plainKeysInFreeText() throws {
        var generator = Obfuscator(seed: 7)
        let others = ["user", "region", "order_id", "screen", "retryCount"]
        let allowing = RedactionPolicy(allowedTextKeys: others)
        let hidden = RedactionPolicy.replacement
        for key in RedactionPolicy.defaultAllowedTextKeys + others {
            let isDefault = RedactionPolicy.defaultAllowedTextKeys.contains(key)
            for _ in 0..<20 {
                let (value, other) = (generator.harmlessValue(), generator.harmlessValue())
                let data = try JSONSerialization.data(withJSONObject: [key: value], options: .withoutEscapingSlashes)
                let json = String(decoding: data, as: UTF8.self)
                let lines = [
                    ("\(key)=\(value)", "\(key)=\(hidden)"), ("\(key): \(value)", "\(key): \(hidden)"),
                    ("done \(key)=\(value) count=\(other)", "done \(key)=\(hidden)"), (json, "{\"\(key)\":\(hidden)"),
                    ("got \(json) in 3 ms", "got {\"\(key)\":\(hidden)"),
                ]
                for (line, cut) in lines {
                    #expect(allowing.redact(text: line) == line, "\(line.debugDescription)")
                    #expect(policy.redact(text: line) == (isDefault ? line : cut), "\(line.debugDescription)")
                }
            }
        }
    }

    // MARK: Property: generated secrets

    @Test("Generated JWTs, hex and Base64 tokens, card numbers, IBANs and emails are found in text and values")
    func generatedSecrets() throws {
        var generator = Obfuscator(seed: 2026)
        for _ in 0..<500 {
            let secret = generator.detectableSecret()
            let text = policy.redact(text: "value \(secret) end")
            #expect(!text.contains(secret), "\(secret) in \(text)")
            let json = try JSONSerialization.data(withJSONObject: ["note": "see \(secret)", "list": [secret]])
            let stored = String(decoding: policy.redact(body: json, contentType: "application/json").body, as: UTF8.self)
            #expect(!stored.contains(secret.replacingOccurrences(of: "/", with: "\\/")) && !stored.contains(secret), "\(secret) in \(stored)")
        }
    }

    // MARK: Usefulness

    @Test("Plain keys that are not secret keep their values")
    func ordinaryKeys() throws {
        let keys = [
            "name", "title", "page", "count", "items", "status", "created_at", "updatedAt", "color", "size", "price",
            "city", "country", "language", "version", "build", "order", "total", "limit", "offset", "query", "sort",
            "filter", "width", "height", "enabled", "visible", "category", "label", "message", "user-name", "Content.Type",
        ]
        for key in keys {
            #expect(!policy.isSensitive(name: key), "\(key)")
            let value = "value \(key.count) of \(key)"
            let json = try JSONSerialization.data(withJSONObject: [key: value])
            let (stored, outcome) = policy.redact(body: json, contentType: "application/json")
            #expect(outcome == .unchanged)
            #expect((try JSONSerialization.jsonObject(with: stored) as? [String: String])?[key] == value)
            let form = Data("\(key)=\(value.replacingOccurrences(of: " ", with: "+"))".utf8)
            #expect(policy.redact(body: form, contentType: "application/x-www-form-urlencoded") == (form, .unchanged))
        }
    }

    @Test("Allowlisted headers, ordinary log lines and allowed query parameters are kept")
    func ordinaryRecords() throws {
        let headers = [
            HTTPHeader(name: "Accept", value: "application/json, text/plain;q=0.9"), HTTPHeader(name: "Accept-Encoding", value: "gzip, br"),
            HTTPHeader(name: "Accept-Language", value: "en-US;q=1.0, tr;q=0.8"), HTTPHeader(name: "Cache-Control", value: "no-cache, max-age=0"),
            HTTPHeader(name: "Content-Encoding", value: "gzip"), HTTPHeader(name: "Content-Length", value: "348"),
            HTTPHeader(name: "Content-Type", value: "multipart/form-data; boundary=----WebKitFormBoundaryAbc123"),
            HTTPHeader(name: "ETag", value: "W/\"5e-1a2b\""), HTTPHeader(name: "User-Agent", value: "DevToolsDemo/2.0 CFNetwork/1568.100.1 Darwin/24.0.0"),
        ]
        #expect(policy.redact(headers: headers) == headers)
        let lines = [
            "GET /v1/items 200 in 35 ms", "Loaded 42 items for user 7", "Retrying request (attempt 2 of 3)",
            "Cache hit for items-page-2", "Order E621E1F8-C36C-495A-93FC-0C247A3E6E5F placed", "The request timed out.",
            "Sync finished at 12:30:45, 3 changes", "Opened https://example.com/docs/getting-started",
            "Giriş başarılı, 3 öğe yüklendi", "Family joined the café", "Загружено 5 элементов", "設定を保存しました",
            "GET /v1/items status=200 duration_ms=35 count=3", "path=/v1/items method=GET", #"{"count":3,"status":"ok"}"#,
            "[INFO] Loaded {0} of [1/3]",
        ]
        for line in lines { #expect(policy.redact(text: line) == line) }
        // The digits of a UUID can pass the Luhn check; they are not laid out as a card number.
        for _ in 0..<5_000 {
            let line = "Order \(UUID().uuidString) placed, ref \(UUID().uuidString.lowercased())"
            #expect(policy.redact(text: line) == line)
        }
        #expect(policy.redact(text: "id AB123456-1234-4234-8230-ABCDEF123456") == "id AB123456-1234-4234-8230-ABCDEF123456")
        let url = try #require(URL(string: "https://e.com/v1/items/42?page=2&sort=asc"))
        #expect(RedactionPolicy(allowedQueryParameters: ["page", "sort"]).redact(url: url) == url.absoluteString)
    }
}
