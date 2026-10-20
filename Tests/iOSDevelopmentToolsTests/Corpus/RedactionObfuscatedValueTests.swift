import Testing
@testable import iOSDevelopmentTools

/// Separators and values written to get past the redactor: look-alike separators, values glued
/// to quotes and brackets, arrays and objects, values on the lines below.
@Suite("Redaction corpus: obfuscated separators and values")
struct RedactionObfuscatedValueTests {
    let redactor = Redactor()

    @Test("punctuation outside ASCII after a secret name is a separator", arguments: [
        ("password\u{A789}hunter2", "password[REDACTED]"),
        ("password \u{A789} hunter2", "password [REDACTED]"),
        ("password\u{02F8}hunter2", "password[REDACTED]"),
        ("password\u{0589}hunter2", "password[REDACTED]"),
        ("token\u{2192}hunter2", "token[REDACTED]"),
        ("\u{1D429}\u{1D41A}\u{1D42C}\u{1D42C}\u{1D430}\u{1D428}\u{1D42B}\u{1D41D}\u{A789}hunter2",
         "\u{1D429}\u{1D41A}\u{1D42C}\u{1D42C}\u{1D430}\u{1D428}\u{1D42B}\u{1D41D}[REDACTED]"),
        ("pass\u{200B}word\u{A789}hunter2", "pass\u{200B}word[REDACTED]"),
        ("password\u{FE13}hunter2", "password\u{FE13}[REDACTED]"),
    ])
    func lookAlikeSeparators(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // Such punctuation separates whatever comes before it, also after other names and after a
    // boundary or a space.
    @Test("punctuation outside ASCII after other words is a separator too", arguments: [
        ("Tokyo\u{00B7}Osaka\u{00B7}Kyoto", "Tokyo[REDACTED]"),
        ("user\u{2192}bob", "user[REDACTED]"),
        ("my_k$ e%79\u{2254}S3CRETV&b=2", "my_k$ e%79[REDACTED]"),
        ("a;\u{2254}S3CRETV", "a;[REDACTED]"),
        ("key \u{2254}S3CRETV", "key [REDACTED]"),
    ])
    func lookAlikeSeparatorsAfterOtherWords(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // The look-alike separator may sit inside the name, so where the name and the value end
    // cannot be told: the rest of the line goes, and the lines below it as a value goes on.
    @Test("a look-alike separator inside a name hides the rest of the line and what follows it", arguments: [
        ("pass\u{00B7}word='hunter2' next", "pass[REDACTED]"),
        ("pass\u{2027}wd: hunter2", "pass[REDACTED]"),
        ("SECRET_K\u{2010}EY=hunter2\nnext", "SECRET_K\u{2010}EY=[REDACTED]\nnext"),
        ("pa\u{00AD}ss\u{00B7}word :\n  <hunter2> next", "pa\u{00AD}ss[REDACTED]\n  [REDACTED]"),
        ("DB_SECRET_KE\u{2010}Y\n=\n<hunter2>", "DB_SECRET_KE\u{2010}Y\n=\n[REDACTED]"),
        ("pass\u{2027}word\nS3CRETV", "pass[REDACTED]\n[REDACTED]"),
        ("- p\u{2027}in :\n  (S3CRETV)", "- p[REDACTED]\n  [REDACTED]"),
    ])
    func lookAlikeSeparatorInName(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a value glued to separators, quotes and brackets is hidden with them", arguments: [
        ("pass:word: hunter2", "pass:[REDACTED]"),
        ("pass:word='hunter2' next", "pass:[REDACTED]"),
        ("password=x\"hunter2\" next", "password=[REDACTED]"),
        ("token=YWJj== user=bob", "token=[REDACTED]"),
        ("<password:>hunter2</password:>", "<password:>[REDACTED]"),
        ("password=)hunter2 next", "password=[REDACTED]"),
    ])
    func valuesEndingInSeparators(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a value spelled with letters that expand keeps whole characters")
    func expandedLetters() {
        #expect(redactor.redact("password=stra\u{00DF}e next=1") == "password=[REDACTED]")
        #expect(redactor.redact("token=\u{FB01}le next=1") == "token=[REDACTED]")
        #expect(redactor.redact("status=\u{FB01}le password=x") == "status=\u{FB01}le password=[REDACTED]")
    }

    @Test("hides an array or object value whole", arguments: [
        ("{\"password\":[\"hunter2\"]}", "{\"password\":\"[REDACTED]\"}"),
        ("{\"password\":{\"v\":\"hunter2\"}}", "{\"password\":\"[REDACTED]\"}"),
        ("{\"token\":[\"a]\",{\"b\":[\"hunter2\"]}],\"status\":\"ok\"}", "{\"token\":\"[REDACTED]\",\"status\":\"ok\"}"),
        ("{\"password\": [\n  \"hunter2\"\n], \"status\": \"ok\"}", "{\"password\": \"[REDACTED]\", \"status\": \"ok\"}"),
        ("log {\"password\":[\"hunter2\"]}", "log {\"password\":\"[REDACTED]\"}"),
        ("password=[hunter2] next", "password=[REDACTED]"),
        ("password={hunter2} next", "password=[REDACTED]"),
        ("password=(hunter2) next", "password=[REDACTED]"),
        ("{\\\"password\\\":[\\\"hunter2\\\"]}", "{\\\"password\\\":[REDACTED]"),
        ("password=[REDACTED] next", "password=[REDACTED]"),
    ])
    func structuredValues(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("an array or object that is never closed is hidden to the end of the text")
    func unclosedStructuredValue() {
        #expect(redactor.redact("{\"password\":[\"hunter2\",\n\"more\"") == "[REDACTED]")
    }

    @Test("a quoted value glued to more text is hidden with it")
    func gluedQuotedValue() {
        #expect(redactor.redact("password=\"hun\"\u{0301}ter2\" next") == "password=\"[REDACTED]\"[REDACTED]")
        // The quote that seemed to close the value may have opened another one.
        #expect(redactor.redact("msg=\"a=\"b\nS3CRETV\"\"\nstatus=2") == "msg=\"[REDACTED]\"[REDACTED]\n[REDACTED]\n[REDACTED]")
    }

    @Test("hides a value after line breaks and other whitespace", arguments: [
        ("log {\"password\":\n\"hunter2\"}", "log {\"password\":\n\"[REDACTED]\"}"),
        ("log {\"password\"\n:\n\"hunter2\"}", "log {\"password\"\n:\n\"[REDACTED]\"}"),
        ("password:\n  hunter2", "password:\n  [REDACTED]"),
        ("password\n= hunter2", "password\n= [REDACTED]"),
        ("password\u{2028}=hunter2", "password\n=[REDACTED]"),
        ("password\u{0085}=hunter2", "password\n=[REDACTED]"),
        ("password\u{000B}=hunter2", "password\n=[REDACTED]"),
        ("password\u{000C}=hunter2", "password\n=[REDACTED]"),
        ("password=hunter2\u{2028}next", "password=[REDACTED]\n[REDACTED]"),
        ("p\u{0430}ssword\nS3CRETV", "[REDACTED]\n[REDACTED]"),
        ("<key>p\u{0430}ssword</key>\n<string>S3CRETV</string>", "<[REDACTED]\n[REDACTED]</string>"),
    ])
    func lineBreaks(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // A line that ends open (`(`, `[`, `=`, `"""`) passes its value on to the next line; one that
    // ends with a letter, a closing quote or bracket or a full stop does not.
    @Test("a value hidden to the end of its line goes on below only when the line ends open", arguments: [
        ("user=bob msg=\"hi\"\nstatus=200", "user=[REDACTED]\nstatus=200"),
        ("user=bob.\nstatus=200", "user=[REDACTED]\nstatus=200"),
        ("password=(\nS3CRETV)", "password=[REDACTED]\n[REDACTED]"),
        ("token=[\n\"S3CRETV\"\n]", "token=[REDACTED]"),
        // Which of the quotes in `"""` closes the value cannot be told: the lines after it go too.
        ("key=\"\"\"\nS3CRETV\n\"\"\"\nstatus=200", "key=\"\"[REDACTED]\n[REDACTED]\n[REDACTED]\n[REDACTED]"),
        ("x\"y \u{2254}\"\"\"\nS3CRETV\n\"\"\"", "x\"y [REDACTED]\n[REDACTED]\n[REDACTED]"),
    ])
    func openLineEnds(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("hides YAML block scalars and tagged values", arguments: [
        ("password: |\n  hunter2\n  more\nstatus: 200", "password: [REDACTED]\n  [REDACTED]\n  [REDACTED]\nstatus: 200"),
        ("password: >-\n  hunter2\n\n  more\nstatus: 200", "password: [REDACTED]\n  [REDACTED]\n\n  [REDACTED]\nstatus: 200"),
        ("password: |2\n   hunter2\nstatus: 200", "password: [REDACTED]\n   [REDACTED]\nstatus: 200"),
        ("password: !!binary aHVudGVyMg== next", "password: [REDACTED]"),
        ("password: >hunter2", "password: [REDACTED]"),
    ])
    func yamlValues(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a separator with no name hides the rest of its line", arguments: [
        ("=hunter2 x\nnext", "=[REDACTED]\nnext"),
        ("status=200, =hunter2 x", "status=200, =[REDACTED]"),
        ("<:password>b", "<:[REDACTED]"),
        ("=\n  hunter2\nnext", "=\n  [REDACTED]\nnext"),
        ("=====\nHeader\n=====", "=====\n[REDACTED]\n====="),
    ])
    func missingNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a name that ends in a bracket keeps its brackets and is not plain", arguments: [
        ("f(x)=5 next=1", "f(x)=[REDACTED]"),
        ("arr[0]=5 next=1", "arr[0]=[REDACTED]"),
        ("status=200 (pass)=hunter2 x=1", "status=200 (pass)=[REDACTED]"),
    ])
    func bracketNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }
}
