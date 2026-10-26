import Foundation

/// What redaction did to a stored body.
public enum RedactionOutcome: String, Sendable, Hashable, Codable {
    /// The body was parsed and is stored as it was sent.
    case unchanged
    /// The body was parsed and redaction changed it: one or more values were hidden, a multipart
    /// body was written again, line separators in its text were folded to line feeds, or JSON in
    /// UTF-16 or UTF-32 was stored as UTF-8.
    case redacted
    /// The body was not stored: it could not be parsed fully, its content type is not one that
    /// is parsed, it was cut off, or it was larger than
    /// ``RedactionPolicy/maximumBodySize``. The stored bytes are a note such as
    /// `[body omitted: 512 bytes, application/xml]`.
    case omitted
}

extension RedactionPolicy {
    /// The body with secrets hidden.
    ///
    /// The body is read with a parser chosen by its content type:
    ///
    /// - **JSON** (`application/json`, `…/json`, `…+json`), in UTF-8, UTF-16 or UTF-32: read with a
    ///   JSON parser and used only when `JSONSerialization` reads the same tree. Keys are compared
    ///   after their escapes are decoded, at every depth, inside arrays and for every repetition
    ///   of a key. A hidden value of any type becomes the string `"[REDACTED]"`, and a string or
    ///   name in which something is found is written again escaped, so the stored text is still
    ///   valid JSON, as sent apart from what is hidden. Names written as values
    ///   (`{"name":"Authorization","value":…}`, JSON Patch `{"path":"/password","value":…}`,
    ///   `[["Authorization","…"]]`) hide their values too; see ``redact(text:)`` for the strings.
    /// - **Forms** (`application/x-www-form-urlencoded`): fields are split at `&` and at the first
    ///   `=`, and names and values are decoded (`+` is a space, then percent-decoding as UTF-8).
    ///   A field whose decoded name hides its value shows `name=[REDACTED]`; other values, names
    ///   and fields without `=` are read as free text. The body is read only when it is strict:
    ///   printable ASCII without `;`, every `%` the start of an escape, and no name spelled two
    ///   ways (`a.b` and `a_b`, `pass%77ord` and `password`, `Note` and `note`).
    /// - **Multipart form data**: every part is written again with its field name and its
    ///   `type/subtype`. Of its other headers, `Content-Length` and `Content-Transfer-Encoding`
    ///   keep their value only in their form, which is not read as free text: a `Content-Length`
    ///   of ASCII digits in which the value detectors find nothing (such as a card number), and a
    ///   `Content-Transfer-Encoding` of `7bit`, `8bit`, `binary`, `base64` or `quoted-printable`,
    ///   written in lowercase (`BASE64` as `base64`). Any other value of theirs is written as
    ///   `[REDACTED]` (`Content-Length: pin-4831` as `Content-Length: [REDACTED]`).
    ///   `Content-ID`, `Content-Description`, `Content-Language`, `Content-Location` and
    ///   `Content-Encoding` keep their name with the value hidden; any other is written as
    ///   `[REDACTED]: [REDACTED]`, whatever ``allowedHeaders`` lists. A part whose name hides its
    ///   value shows `[REDACTED]`, and any other part is read by its own content type
    ///   (`text/plain` when it has none). Uploaded files, nested multipart bodies,
    ///   parts in a transfer encoding other than `7bit`, `8bit` or `binary` and parts of other
    ///   types are omitted like a body. A part that holds a name (`label`, `name`, `type`, …)
    ///   names a secret unless its content is plain UTF-8 text naming none. The body is read only
    ///   with a single unquoted `boundary` of at most 70 characters, and only when every
    ///   `--boundary` in it, in any case, is a delimiter line that follows a CRLF.
    /// - **Plain text** (`text/plain`): free text, as ``redact(text:)`` reads it.
    ///
    /// Anything else is omitted: no content type, another content type (XML, HTML, binary data),
    /// a charset other than UTF-8 (or UTF-16 and UTF-32 for JSON), a body larger than
    /// ``maximumBodySize`` (256 KiB by default), a body that was cut off or cannot be parsed completely —
    /// malformed, nested deeper than ``maximumJSONDepth`` — and a body that a common server parser
    /// (PHP, Werkzeug, Rack, Go, busboy) could split into fields differently, such as a multipart
    /// body with `--boundary` after a bare LF or CR, or a form with a `;`. The result is then a
    /// note such as `[body omitted: 512 bytes, application/xml]` and ``RedactionOutcome/omitted``.
    ///
    /// - Parameters:
    ///   - body: The bytes to check.
    ///   - contentType: The `Content-Type` header value, if any.
    ///   - isComplete: `false` when `body` holds only the first part of a longer body.
    public func redact(body: Data, contentType: String?, isComplete: Bool = true) -> (body: Data, outcome: RedactionOutcome) {
        redact(body: body, contentType: contentType, isComplete: isComplete, byteCount: body.count)
    }

    /// As ``redact(body:contentType:isComplete:)``, with the size of the whole body for the note.
    func redact(body: Data, contentType: String?, isComplete: Bool, byteCount: Int) -> (body: Data, outcome: RedactionOutcome) {
        guard isEnabled, !(body.isEmpty && isComplete) else { return (body, .unchanged) }
        let mediaType = MediaType(contentType)
        // A plain-text body is free text, as a log message is; other bodies are documents.
        let length = Self.scalarCount(body)
        let nesting = mediaType?.isPlainText == true ? Nesting.text(length: length) : .document(length: length)
        // One table of readings serves the whole body, with every field and part in it.
        guard isComplete, body.count <= maximumBodySize, let mediaType,
              let (checked, changed) = redact(body: body, as: mediaType, nesting: nesting, compatibility: readings(length: length))
        else {
            return (Data(Self.omissionNote(byteCount: byteCount, contentType: contentType).utf8), .omitted)
        }
        return (checked, changed ? .redacted : .unchanged)
    }

    /// The note stored in place of an omitted body: its size and its content type, `no content
    /// type` or `unreadable content type`.
    static func omissionNote(byteCount: Int, contentType: String?) -> String {
        omitted(byteCount, contentType == nil ? "no content type" : MediaType(contentType)?.essence ?? "unreadable content type")
    }

    /// The note for `count` bytes of `type`.
    static func omitted(_ count: Int, _ type: String) -> String {
        "[body omitted: \(count) \(count == 1 ? "byte" : "bytes"), \(type)]"
    }

    /// The number of scalars in UTF-8 bytes: the bytes that do not continue a scalar. Bytes that
    /// are not UTF-8 count as one scalar each, as they would decode to one replacement character.
    static func scalarCount(_ bytes: some Sequence<UInt8>) -> Int {
        bytes.reduce(0) { $0 + ($1 & 0xC0 == 0x80 ? 0 : 1) }
    }

    /// A body of a known type with secrets hidden, and whether what is stored differs from it;
    /// nil when it is omitted. `nesting` is the body's own: a body passed in is
    /// ``Nesting/document(length:)``, a multipart part one level deeper. `compatibility` is the
    /// one table of readings of the body a part is in, or of the body.
    func redact(body: Data, as type: MediaType, nesting: Nesting, compatibility: CompatibilityText) -> (Data, Bool)? {
        if type.isMultipartFormData {
            // The body is written again part by part; it is unchanged when it was written as the
            // parser writes it and nothing in it was hidden.
            return redactedMultipart(body, type, nesting: nesting, compatibility: compatibility).map { text in
                let written = Data(text.utf8)
                return (written, written != body)
            }
        }
        if type.isJSON {
            return type.isUnicode ? redact(jsonBody: body, charset: type.charset, nesting: nesting, compatibility: compatibility) : nil
        }
        guard type.isUTF8, let text = BodyText.utf8(body, dropsByteOrderMark: true) else { return nil }
        if type.isForm {
            guard let redacted = redact(form: text, nesting: nesting, compatibility: compatibility) else { return nil }
            return redacted == text ? (body, false) : (Data(redacted.utf8), true)
        }
        guard type.isPlainText else { return nil }
        let redacted = redact(text, nesting: nesting, compatibility: compatibility)
        return redacted == text ? (body, false) : (Data(redacted.utf8), true)
    }

    // MARK: JSON

    /// A JSON body in UTF-8, UTF-16 or UTF-32, told apart by its first bytes as
    /// `JSONSerialization` tells them. A body in UTF-16 or UTF-32 is stored as UTF-8. A body whose
    /// bytes are in another encoding than its `charset` names is omitted: a server that decodes it
    /// by the charset reads other text. A byte order mark at the start is left out on every OS
    /// version (see ``BodyText``), and any other one is not JSON.
    private func redact(jsonBody body: Data, charset: String?, nesting: Nesting, compatibility: CompatibilityText) -> (Data, Bool)? {
        let encoding = Self.jsonEncoding(Array(body.prefix(4)))
        guard Self.charset(charset, allows: encoding), let text = BodyText.json(body, in: encoding) else { return nil }
        let isUTF8 = encoding == .utf8
        let scalars = Array(text.unicodeScalars)
        // The UTF-8 of the text is the body after its byte order mark.
        let utf8 = isUTF8 ? body.suffix(text.utf8.count) : nil
        guard let document = try? JSONDocument(scalars, utf8: utf8, allowsFragments: true, nesting: nesting) else { return nil }
        let spans = Self.merged(document.secretSpans(using: self, compatibility: compatibility))
        guard !spans.isEmpty || !isUTF8 else { return (body, false) }
        return (Data(Self.replacing(spans, in: scalars).utf8), true)
    }

    /// Whether bytes in `encoding` are what a `charset` parameter names; any of them when there is
    /// none, as `JSONSerialization` reads them.
    private static func charset(_ charset: String?, allows encoding: String.Encoding) -> Bool {
        switch charset {
        case nil: true
        case "utf-8", "utf8", "us-ascii": encoding == .utf8
        case "utf-16": encoding == .utf16LittleEndian || encoding == .utf16BigEndian
        case "utf-16le": encoding == .utf16LittleEndian
        case "utf-16be": encoding == .utf16BigEndian
        case "utf-32": encoding == .utf32LittleEndian || encoding == .utf32BigEndian
        case "utf-32le": encoding == .utf32LittleEndian
        case "utf-32be": encoding == .utf32BigEndian
        default: false
        }
    }

    /// The encoding of JSON text from its byte order mark or the zero bytes of its first
    /// characters (RFC 4627, section 3).
    private static func jsonEncoding(_ start: [UInt8]) -> String.Encoding {
        let bytes = start + Array(repeating: 1, count: 4 - start.count)
        switch (bytes[0], bytes[1], bytes[2], bytes[3]) {
        case (0, 0, 0xFE, 0xFF), (0, 0, 0, _): return .utf32BigEndian
        case (0xFF, 0xFE, 0, 0), (_, 0, 0, 0): return .utf32LittleEndian
        case (0xFE, 0xFF, _, _), (0, _, _, _): return .utf16BigEndian
        case (0xFF, 0xFE, _, _), (_, 0, _, _): return .utf16LittleEndian
        default: return .utf8
        }
    }

    // MARK: Forms

    /// A form body or query string split on `&`, with every name and value percent-decoded with
    /// the platform API; nil when it is not strict (see ``isStrictForm(_:)``) or a field does
    /// not decode. Fields are split scalar by scalar, as a server reads the bytes.
    ///
    /// The form is read twice, field by field: once for the fields that name a secret in their
    /// value, as `label=Password&value=…` does (see ``NamingFields``), and once to write it, into
    /// one string. No array of its fields is kept, so a form of many fields takes little more
    /// memory than its text.
    func redact(form text: String, nesting: Nesting, compatibility: CompatibilityText) -> String? {
        guard Self.isStrictForm(text) else { return nil }
        var naming = NamingFields()
        for raw in FormFields(text) {
            guard let field = FormField(raw) else { return nil }
            naming.read(Self.namingField(name: field.name, value: field.value), compatibility: compatibility)
        }
        var output = ""
        output.reserveCapacity(text.utf8.count)
        for (index, raw) in FormFields(text).enumerated() {
            guard let field = FormField(raw) else { return nil }
            if index > 0 { output += "&" }
            let hidesValue = naming.hidesValue(at: index, of: Self.namingField(name: field.name, value: field.value))
            output += redact(field: field, hidesValue: hidesValue, nesting: nesting, compatibility: compatibility)
        }
        return output
    }

    /// A field of a form or a URL query as ``NamingFields`` reads it.
    static func namingField(name: String, value: String?) -> NamingFields.Field {
        (Array(name.unicodeScalars), value.map { .string(Array($0.unicodeScalars)) } ?? .other)
    }

    /// The fields of a form, split at every `&`, one after another.
    private struct FormFields: Sequence, IteratorProtocol {
        private let scalars: String.UnicodeScalarView
        private var start: String.UnicodeScalarView.Index?

        init(_ text: String) {
            scalars = text.unicodeScalars
            start = scalars.startIndex
        }

        mutating func next() -> Substring.UnicodeScalarView? {
            guard let fieldStart = start else { return nil }
            let end = scalars[fieldStart...].firstIndex(of: "&") ?? scalars.endIndex
            start = end == scalars.endIndex ? nil : scalars.index(after: end)
            return scalars[fieldStart..<end]
        }
    }

    /// A form field, as sent and decoded: `+` is a space, then percent-decoding as UTF-8.
    private struct FormField {
        let rawName: Substring
        let rawValue: Substring?
        let name: String
        let value: String?

        init?(_ field: Substring.UnicodeScalarView) {
            guard let equals = field.firstIndex(of: "=") else {
                rawName = Substring(field)
                rawValue = nil
                guard let name = RedactionPolicy.formDecoded(rawName) else { return nil }
                self.name = name
                value = nil
                return
            }
            rawName = Substring(field[..<equals])
            let rawValue = Substring(field[field.index(after: equals)...])
            guard let name = RedactionPolicy.formDecoded(rawName), let value = RedactionPolicy.formDecoded(rawValue) else { return nil }
            self.rawValue = rawValue
            self.name = name
            self.value = value
        }
    }

    /// A field is a name, `=` and a value. The name is free text too, since it can hold a field or
    /// a card number of its own (`password%3Dhunter2=x`, `{"password":"…"}` sent as a form); a
    /// field without `=` is free text. The value is hidden when the name hides it or another field
    /// names a secret.
    private func redact(field: FormField, hidesValue: Bool, nesting: Nesting, compatibility: CompatibilityText) -> String {
        guard let rawValue = field.rawValue, let value = field.value else {
            return shown(field.name, as: redact(field.name, nesting: nesting, compatibility: compatibility), raw: field.rawName)
        }
        let shownName = shown(field.name, as: redactedName(field.name, nesting: nesting, compatibility: compatibility), raw: field.rawName)
        if hidesValue || self.hidesValue(ofKey: field.name.unicodeScalars) { return shownName + "=" + Self.replacement }
        return shownName + "=" + shown(value, as: redact(value, nesting: nesting, compatibility: compatibility), raw: rawValue)
    }

    /// Decoded text after redaction: as sent when nothing was found, encoded again otherwise.
    private func shown(_ text: String, as redacted: String, raw: Substring) -> String {
        redacted == text ? String(raw) : Self.formEncoded(redacted)
    }

    /// Whether common servers all split a form body or URL query into the same fields with the
    /// same names. Every character is printable ASCII other than `;`, every `%` starts an escape of
    /// two hex digits, and no two fields spell one name differently. Each rule closes a split that
    /// some server makes differently: Rack, Python before 3.9.2 and Go before 1.17 also split at
    /// `;`; Rack drops spaces after a separator; servers keep, drop or reject a bare `%`; and PHP
    /// reads `a.b`, `a b` and `a_b` as one name, which decoding (`pass%77ord`) and case can
    /// also make one.
    static func isStrictForm(_ text: String) -> Bool {
        // Printable ASCII only, so the UTF-8 bytes are the scalars.
        let bytes = Array(text.utf8)
        for (i, byte) in bytes.enumerated() {
            guard (0x21...0x7E).contains(byte), byte != UInt8(ascii: ";") else { return false }
            guard byte == UInt8(ascii: "%") else { continue }
            guard i + 2 < bytes.count, isHexDigit(bytes[i + 1]), isHexDigit(bytes[i + 2]) else { return false }
        }
        var spellings: [String: Substring] = [:]
        for field in text.unicodeScalars.split(separator: "&") {
            let rawName = Substring(field.prefix { $0 != "=" })
            guard let name = formDecoded(rawName) else { return false }
            let folded = name.utf8.drop { $0 == UInt8(ascii: " ") }.map { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: ".") ? UInt8(ascii: "_") : $0 }
            let serverName = String(decoding: folded, as: UTF8.self).lowercased()
            if let earlier = spellings.updateValue(rawName, forKey: serverName), earlier != rawName { return false }
        }
        return true
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        ASCII.isDigit(byte) || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte | 0x20)
    }

    /// `+` as a space, then percent-decoding as UTF-8; nil for a bad `%` escape or bytes that are
    /// not UTF-8. `+` is replaced byte by byte: `replacingOccurrences` compares characters and
    /// leaves a `+` that a combining mark follows. The bytes are copied into a string once, not
    /// appended as scalars one at a time, which took half the time of a large form.
    static func formDecoded(_ text: some StringProtocol) -> String? {
        let spaced = text.utf8.map { $0 == UInt8(ascii: "+") ? UInt8(ascii: " ") : $0 }
        return String(decoding: spaced, as: UTF8.self).removingPercentEncoding
    }

    /// Percent-encodes what form decoding would change, keeping `[` and `]` readable, so a
    /// replaced value still reads `[REDACTED]`.
    static func formEncoded(_ text: String) -> String {
        var output = ""
        for byte in text.utf8 {
            if ASCII.isAlphanumeric(byte) || "*-._[]".utf8.contains(byte) {
                output.unicodeScalars.append(Unicode.Scalar(byte))
            } else if byte == UInt8(ascii: " ") {
                output += "+"
            } else {
                output += "%" + (byte < 0x10 ? "0" : "") + String(byte, radix: 16, uppercase: true)
            }
        }
        return output
    }
}
