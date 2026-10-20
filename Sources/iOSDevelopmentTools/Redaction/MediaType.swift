/// A `Content-Type` value, read strictly as RFC 9110 writes it: `type/subtype` and
/// `; name=value` parameters whose value is a token or a quoted string.
struct MediaType: CustomStringConvertible {
    /// `type/subtype` in lowercase, such as `application/json`.
    let essence: String
    /// The subtype in lowercase, such as `json` or `problem+json`.
    let subtype: String
    /// The parameters in order, with lowercase names; quoted values without their quotes.
    let parameters: [HeaderValueReader.Parameter]

    /// nil when there is no content type, or it is not `type/subtype` and well-formed parameters.
    init?(_ text: String?) {
        guard let text else { return nil }
        var reader = HeaderValueReader(Array(text.unicodeScalars))
        reader.skipWhitespace()
        guard let type = reader.token(), reader.consume("/"), let subtype = reader.token() else { return nil }
        guard let parameters = reader.parameters() else { return nil }
        self.essence = (type + "/" + subtype).lowercased()
        self.subtype = subtype.lowercased()
        self.parameters = parameters
    }

    var description: String { essence }

    var isJSON: Bool { subtype == "json" || subtype.hasSuffix("+json") }
    var isForm: Bool { essence == "application/x-www-form-urlencoded" }
    var isMultipartFormData: Bool { essence == "multipart/form-data" }
    var isPlainText: Bool { essence == "text/plain" }

    /// The values of every parameter with this name.
    func values(of name: String) -> [String] {
        parameters.filter { $0.name == name }.map(\.value)
    }

    /// Whether the text is UTF-8: no `charset`, or `utf-8` or `us-ascii`.
    var isUTF8: Bool { charset.map(Self.utf8Charsets.contains) ?? true }

    /// Whether the text is in an encoding that `JSONSerialization` tells apart by itself: UTF-8,
    /// UTF-16 or UTF-32. JSON in another charset would be read differently by the server.
    var isUnicode: Bool { charset.map { Self.utf8Charsets.contains($0) || Self.wideCharsets.contains($0) } ?? true }

    /// The charset in lowercase; `"?"` when several are given, which servers read differently.
    var charset: String? {
        let charsets = values(of: "charset").map { $0.lowercased() }
        guard !charsets.isEmpty else { return nil }
        return charsets.count == 1 ? charsets[0] : "?"
    }

    private static let utf8Charsets: Set<String> = ["utf-8", "utf8", "us-ascii"]
    private static let wideCharsets: Set<String> = ["utf-16", "utf-16le", "utf-16be", "utf-32", "utf-32le", "utf-32be"]
}

/// Reads the `token`, `quoted-string` and parameter syntax shared by `Content-Type` and
/// `Content-Disposition`.
struct HeaderValueReader {
    /// A `name=value` parameter: the name in lowercase, a quoted value without its quotes.
    struct Parameter {
        let name: String
        let value: String
        /// Whether the value was a quoted string.
        let isQuoted: Bool
    }

    private let scalars: [Unicode.Scalar]
    private var position = 0

    init(_ scalars: [Unicode.Scalar]) { self.scalars = scalars }

    /// `*( OWS ";" OWS name "=" value ) OWS` up to the end; nil when anything else is there.
    mutating func parameters() -> [Parameter]? {
        var parameters: [Parameter] = []
        while true {
            skipWhitespace()
            if position == scalars.count { return parameters }
            guard consume(";") else { return nil }
            skipWhitespace()
            guard let name = token(), consume("=") else { return nil }
            let isQuoted = scalars.indices.contains(position) && scalars[position] == "\""
            guard let value = isQuoted ? quotedString() : token() else { return nil }
            parameters.append(Parameter(name: name.lowercased(), value: value, isQuoted: isQuoted))
        }
    }

    mutating func token() -> String? {
        let start = position
        while position < scalars.count, Self.isTokenCharacter(scalars[position]) { position += 1 }
        return position > start ? String(String.UnicodeScalarView(scalars[start..<position])) : nil
    }

    /// A quoted string; its content may hold UTF-8 text, as browsers send file and field names.
    /// A `\` escape is kept as written: servers differ in whether they decode it, and a name with
    /// a `\` is not plain, so its value is hidden either way.
    private mutating func quotedString() -> String? {
        position += 1
        var value = String.UnicodeScalarView()
        while position < scalars.count {
            let scalar = scalars[position]
            position += 1
            switch scalar {
            case "\"": return String(value)
            case "\\":
                guard position < scalars.count, scalars[position] != "\r", scalars[position] != "\n" else { return nil }
                value.append(scalar)
                value.append(scalars[position])
                position += 1
            case "\r", "\n", "\0": return nil
            default: value.append(scalar)
            }
        }
        return nil
    }

    mutating func consume(_ scalar: Unicode.Scalar) -> Bool {
        guard position < scalars.count, scalars[position] == scalar else { return false }
        position += 1
        return true
    }

    mutating func skipWhitespace() {
        while position < scalars.count, scalars[position] == " " || scalars[position] == "\t" { position += 1 }
    }

    static func isTokenCharacter(_ scalar: Unicode.Scalar) -> Bool {
        guard scalar.isASCII else { return false }
        return ASCII.isAlphanumeric(UInt8(scalar.value)) || "!#$%&'*+-.^_`|~".unicodeScalars.contains(scalar)
    }
}
