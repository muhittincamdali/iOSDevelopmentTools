import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A name passed in `additionalSecretNames` is read wherever the default secret names are: in keys,
/// in free text, in names written as values, in URL hosts and path segments and in query
/// parameters that name a secret. An added name of five or more letters counts anywhere in a key,
/// a shorter one as a word of it or at its end.
@Suite("Redaction: added secret names")
struct RedactionAddedSecretNameTests {
    let policy = RedactionPolicy(additionalSecretNames: ["Ticket", "pan"])

    func json(_ text: String, _ policy: RedactionPolicy? = nil) -> String {
        String(decoding: (policy ?? self.policy).redact(body: Data(text.utf8), contentType: "application/json").body, as: UTF8.self)
    }

    func form(_ text: String) -> String {
        String(decoding: policy.redact(body: Data(text.utf8), contentType: "application/x-www-form-urlencoded").body, as: UTF8.self)
    }

    func url(_ text: String, _ policy: RedactionPolicy? = nil) throws -> String {
        (policy ?? self.policy).redact(url: try #require(URL(string: text)))
    }

    @Test("an added name hides the value of a key that holds it")
    func keys() {
        #expect(json(#"{"ticket":"Qz77","x-ticket-id":"Qz78","TicketNumber":"Qz79","pan":"Qz80","user_pan":"Qz81","panel":"ok"}"#)
            == #"{"ticket":"[REDACTED]","x-ticket-id":"[REDACTED]","TicketNumber":"[REDACTED]","pan":"[REDACTED]","user_pan":"[REDACTED]","panel":"ok"}"#)
        #expect(form("ticket=Qz77&panel=ok") == "ticket=[REDACTED]&panel=ok")
        #expect(policy.redact(headers: [HTTPHeader(name: "X-Ticket", value: "Qz77")]) == [HTTPHeader(name: "X-Ticket", value: "[REDACTED]")])
    }

    @Test("an added name written without a separator in free text cuts the text after it", arguments: [
        ("ticket Qz77", "ticket [REDACTED]"), ("login ticket Qz77 ok", "login ticket [REDACTED]"), ("my pan Qz77", "my pan [REDACTED]"),
        ("ticket: Qz77", "ticket: [REDACTED]"),
    ])
    func freeText(input: String, expected: String) {
        #expect(policy.redact(text: input) == expected)
        #expect(RedactionPolicy.default.redact(text: input) != expected || input.contains(":"))
    }

    @Test("an added name written as a value hides the value beside it")
    func namesAsValues() {
        #expect(json(#"{"name":"ticket","value":"Qz77"}"#) == #"{"name":"ticket","value":"[REDACTED]"}"#)
        #expect(json(#"[["Ticket","Qz77"],["Accept","x"]]"#) == #"[["Ticket","[REDACTED]"],["Accept","x"]]"#)
        #expect(json(#"[{"op":"replace","path":"/user/ticket","value":"Qz77"}]"#) == #"[{"op":"replace","path":"/user/ticket","value":"[REDACTED]"}]"#)
        #expect(json(#"{"OptionName":"DbTicket","Value":"Qz77"}"#) == #"{"OptionName":"DbTicket","Value":"[REDACTED]"}"#)
        #expect(form("label=ticket&value=Qz77") == "label=ticket&value=[REDACTED]")
        // The default policy does not know the name.
        #expect(json(#"{"name":"ticket","value":"Qz77"}"#, .default) == #"{"name":"ticket","value":"Qz77"}"#)
    }

    @Test("an added name in a URL makes the segment after it a value, and hides a host and a query")
    func urls() throws {
        #expect(try url("https://api.example.com/v1/ticket/123") == "https://api.example.com/v1/ticket/:id")
        #expect(try url("https://api.example.com/v1/ticket/123", .default) == "https://api.example.com/v1/ticket/123")
        #expect(try url("myapp://ticket/123") == "myapp://[REDACTED]")
        #expect(try url("https://ticket.example.com/a") == "https://[REDACTED]")
        let query = try url("https://api.example.com/a?label=ticket&value=Qz77")
        #expect(!query.contains("Qz77"))
        #expect(try url("https://api.example.com/a?ticket=Qz77", RedactionPolicy(additionalSecretNames: ["ticket"], allowedQueryParameters: ["ticket"]))
            == "https://api.example.com/a?ticket=[REDACTED]")
    }

    @Test("no allowlist takes an added name")
    func allowlists() {
        let allowing = RedactionPolicy(additionalSecretNames: ["ticket"], allowedHeaders: ["X-Ticket"], allowedQueryParameters: ["ticket_id"], allowedTextKeys: ["ticket"])
        #expect(allowing.allowedHeaders.isEmpty && allowing.allowedQueryParameters.isEmpty)
        #expect(allowing.allowedTextKeys == RedactionPolicy.default.allowedTextKeys)
        #expect(allowing.redact(text: "ticket=Qz77") == "ticket=[REDACTED]")
    }
}
