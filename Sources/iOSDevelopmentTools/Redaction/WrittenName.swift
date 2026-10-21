import Foundation

/// Names written as values: the one rule that decides whether a string names a field whose value
/// is hidden. Every path that reads such a name calls ``namesSecret(_:in:compatibility:)``: JSON
/// objects and arrays (in a body, in a line of text, in a JSON string, in a form value, in a URL
/// query, in a multipart part), form fields, URL queries, multipart parts, and quoted values and
/// markup in free text.
///
/// A field that holds a name (`{"label":"Password","value":…}`) is read by the key rule of
/// ``RedactionPolicy/hidesValue(ofKey:)``, as a key is: its name hides what goes with it unless it is plain ASCII and
/// names no secret. A name in letters outside ASCII (`Şifre`, `Пароль`), in symbols with no letter
/// or digit of their own (`ⓟⓘⓝ`, `🄿🄸🄽`, `🔑`, `𝐩𝐢𝐧`) or with punctuation (`Password:`) counts as
/// secret, whatever it says.
enum WrittenName {
    /// Where a name is written, which decides how it is read.
    enum Place {
        /// The value of the field `field` of an object, a form, a URL query or a multipart body.
        /// When the field holds a name (see ``holdsName(_:)``), the value is read by the key rule;
        /// otherwise it names a secret only when it may be a name (see
        /// ``mayBeName(_:compatibility:)``) whose words name a secret or cannot be read.
        case field([Unicode.Scalar])
        /// The first element of a two-element array, as fetch headers and `URLSearchParams`
        /// entries are written: read by the key rule.
        case pairName
        /// An element of an array: any word of it that names a secret or cannot be read counts.
        case element
        /// A quoted value in free text or markup, or the text of an element, after the key or tag
        /// `key`: read by the key rule when `key` holds a name, and in any case for words that
        /// name a secret or cannot be read.
        case quoted(after: [Unicode.Scalar]?)
    }

    /// Whether `value`, written at `place`, names a field whose value is hidden.
    static func namesSecret(_ value: [Unicode.Scalar], in place: Place, policy: RedactionPolicy, compatibility: CompatibilityText) -> Bool {
        switch place {
        case .field(let field):
            if holdsName(field) { return heldNameNamesSecret(value, field: field, policy: policy, compatibility: compatibility) }
            return mayBeName(value, compatibility: compatibility) && FreeTextScanner.nameNamesSecret(value, policy: policy, compatibility: compatibility)
        case .pairName:
            return heldNameNamesSecret(value, field: nil, policy: policy, compatibility: compatibility)
        case .element:
            return FreeTextScanner.mentionsSecret(value, policy: policy, compatibility: compatibility)
        case .quoted(let key):
            if let key, holdsNameInText(key), heldNameNamesSecret(value, field: key, policy: policy, compatibility: compatibility) { return true }
            return !value.isEmpty && FreeTextScanner.nameNamesSecret(value, policy: policy, compatibility: compatibility)
        }
    }

    // MARK: Fields that hold names

    /// The fields whose value is a name: the names of name and value pairs, as HTTP archives,
    /// JSON Patch, SCIM, forms and configurations write them.
    static let nameFields: Set<String> = ["name", "key", "field", "label", "type", "header", "param", "path", "id", "k", "n"]

    /// The fields that hold a name in records as often as in pairs: a person, a place or a product
    /// (`name`), an identifier (`id`) or a media type (`type`). Beside a name of theirs that is only
    /// written outside plain ASCII, the fields that carry a value are hidden, not the whole record
    /// (see ``mayBeRecordValue(_:field:policy:compatibility:)``).
    static let recordFields: Set<String> = ["name", "id", "type"]

    /// The words of the fields that carry the value of a pair, as HTTP archives, JSON Patch, SCIM,
    /// forms and configurations write it. A field with one of them as a word carries one too
    /// (`ParameterValue`, `defaultValue`, `value_2`, `userData`).
    static let valueWords: Set<String> = ["value", "values", "val", "v", "content", "data", "text", "input", "answer"]

    /// The fields that stay beside a name that names a secret, when they hold a string: the names
    /// of pairs, which are names and not values.
    static let stayingFields: Set<String> = ["name", "key", "field", "header", "param", "path", "k", "n"]

    /// The JSON Patch and SCIM operations, whose `op` stays beside a name.
    private static let operations: Set<String> = ["add", "remove", "replace", "move", "copy", "test"]

    private static let longestField = nameFields.union(["op"]).map(\.count).max() ?? 0

    /// Whether a field holds a name: one of ``nameFields`` in any case, or a field whose own name
    /// is not plain ASCII, which may be one of them disguised (`lab\u{200B}el`, `ⓛⓐⓑⓔⓛ`).
    static func holdsName(_ field: [Unicode.Scalar]) -> Bool {
        if isField(field, oneOf: nameFields) { return true }
        // A field of ASCII letters and digits is plain; only the others need to be read.
        let isAlphanumeric = field.allSatisfy { $0.isASCII && ASCII.isAlphanumeric(UInt8($0.value)) }
        if !field.isEmpty, field.count <= PlainName.maximumKeyLength, isAlphanumeric { return false }
        return PlainName(field) == nil
    }

    /// Whether a key of free text holds a name: as ``holdsName(_:)``, but for `path`, which in a
    /// log line is the route of a request (`path=/v1/users`) and is allowed by default.
    static func holdsNameInText(_ key: [Unicode.Scalar]) -> Bool {
        holdsName(key) && !isField(key, oneOf: ["path"])
    }

    /// Whether the field `field` with the string `value` stays beside a name that names a secret:
    /// the name of a pair, or the `op` of a JSON Patch or SCIM operation.
    static func staysBesideName(_ field: [Unicode.Scalar], value: [Unicode.Scalar]) -> Bool {
        if isField(field, oneOf: stayingFields) { return true }
        guard isField(field, oneOf: ["op"]), value.count <= 7 else { return false }
        return operations.contains(String(String.UnicodeScalarView(value)).lowercased())
    }

    /// Whether the field `field` carries the value of a pair (see ``valueWords``): beside a name
    /// that names a secret it is hidden whole, whatever the name. A field that is not plain ASCII
    /// is hidden by the key rule anyway.
    static func carriesValue(_ field: [Unicode.Scalar]) -> Bool {
        PlainName(field)?.holdsWord(of: valueWords) ?? false
    }

    /// Whether a name held by `field` that the key rule hides only because it is not plain ASCII
    /// may be the value of a record rather than the name of a pair: `field` is one of
    /// ``recordFields``, and the name is written in letters, marks and digits that compatibility
    /// normalization leaves as they are, spaces and printable ASCII punctuation, and names no
    /// secret word as free text reads it (`Ayşe Yılmaz`, `İstanbul`, `image/png`,
    /// `iPhone 15 Pro (256 GB)`, `John O'Brien`). A name in symbols, in styled letters (`ⓟ`, `𝐩`,
    /// `ｐ`), with a format character or one that names a secret is not.
    static func mayBeRecordValue(
        _ value: [Unicode.Scalar], field: [Unicode.Scalar], policy: RedactionPolicy, compatibility: CompatibilityText
    ) -> Bool {
        guard isField(field, oneOf: recordFields), value.count <= PlainName.maximumKeyLength, PlainName(value) == nil,
              value.allSatisfy(isWrittenAsItIs), value.contains(where: { ScalarClass.isLetterOrNumber($0) })
        else { return false }
        // Compared scalar by scalar: `String` equality would take a decomposed `é` for a composed one.
        let text = String(String.UnicodeScalarView(value))
        guard text.precomposedStringWithCompatibilityMapping.unicodeScalars.elementsEqual(value) else { return false }
        return !FreeTextScanner.nameNamesSecret(value, policy: policy, compatibility: compatibility)
    }

    /// Printable ASCII, or a letter, mark or decimal digit of another script.
    private static func isWrittenAsItIs(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.isASCII { return (0x20...0x7E).contains(scalar.value) }
        switch ScalarTable.category(scalar) {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .otherLetter, .nonspacingMark, .spacingMark, .decimalNumber: return true
        default: return false
        }
    }

    /// Whether `field`, in any case, is one of `names`, which are lowercase ASCII.
    static func isField(_ field: [Unicode.Scalar], oneOf names: Set<String>) -> Bool {
        guard field.count <= longestField else { return false }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(field.count)
        for scalar in field {
            guard scalar.isASCII else { return false }
            bytes.append(ASCII.lowercased(UInt8(scalar.value)))
        }
        return names.contains(String(decoding: bytes, as: UTF8.self))
    }

    /// A name held by a field, read by the key rule: anything but a plain-ASCII name that names no
    /// secret names one. Of a `path`, every part between `/` is such a name (see
    /// ``pathNamesSecret(_:)``). The words of a plain name are read as free text reads them too.
    private static func heldNameNamesSecret(
        _ value: [Unicode.Scalar], field: [Unicode.Scalar]?, policy: RedactionPolicy, compatibility: CompatibilityText
    ) -> Bool {
        if let field, isField(field, oneOf: ["path"]) { return pathNamesSecret(value, policy: policy) }
        if policy.hidesValue(ofKey: value) { return true }
        return FreeTextScanner.nameNamesSecret(value, policy: policy, compatibility: compatibility)
    }

    /// Whether a JSON Pointer or SCIM path leads to a value that is hidden: one of its parts
    /// between `/` hides a value by the key rule. The last part names the field (`/user/password`,
    /// SCIM `password`), and a part before it holds the field (`/apiKeys/0`, `/password/hint`), so
    /// the value is inside a secret either way. Array indexes (`0`, and `-` for the end) name
    /// nothing. An empty path, which stands for the whole document, hides the value.
    static func pathNamesSecret(_ path: [Unicode.Scalar], policy: RedactionPolicy) -> Bool {
        var parts = path.split(separator: "/", omittingEmptySubsequences: false)
        if path.first == "/" { parts.removeFirst() }
        return parts.contains { part in !(part.count == 1 && part.first == "-") && policy.hidesValue(ofKey: part) }
    }

    // MARK: Names in other fields

    /// Whether a string is a name rather than a sentence or a document: at most
    /// ``PlainName/maximumKeyLength`` scalars without a line break, with a letter or digit, and
    /// once the punctuation and spaces around it are left out, without `:`, `=`, `,`, `;`, quotes
    /// or brackets, which pair a key with a value or hold one (`Error: token expired`,
    /// `{"password":…}`). A symbol whose compatibility form is a letter or digit (`ⓟ`, `🄿`, `①`)
    /// counts as one, so a name written only in such symbols is a name.
    static func isName(_ scalars: [Unicode.Scalar], compatibility: CompatibilityText) -> Bool {
        guard scalars.count <= PlainName.maximumKeyLength else { return false }
        let isLetterOrDigit = { (scalar: Unicode.Scalar) in Self.isLetterOrDigit(scalar, compatibility: compatibility) }
        guard let first = scalars.firstIndex(where: isLetterOrDigit), let last = scalars.lastIndex(where: isLetterOrDigit) else { return false }
        return !scalars.contains { $0 == "\n" || $0 == "\r" } && !scalars[first...last].contains { notInNames.contains($0) }
    }

    private static let notInNames = Set(":=,;\"'()[]{}<>".unicodeScalars)

    /// Whether a string held by a field that holds no name may be a name: it is one (see
    /// ``isName(_:compatibility:)``), or it is one once its line breaks are read as spaces and its
    /// escapes are decoded (`password` and a line feed, `api`, a line feed and `key`,
    /// `&#x0070;in`, `pass&#119;ord`). A name written so cannot be told from one written plainly,
    /// and a sentence keeps its `:` or `,` either way.
    static func mayBeName(_ scalars: [Unicode.Scalar], compatibility: CompatibilityText) -> Bool {
        if isName(scalars, compatibility: compatibility) { return true }
        guard scalars.count <= PlainName.maximumKeyLength, scalars.contains(where: { $0 == "\n" || $0 == "\r" || $0 == "&" }) else { return false }
        let decoded = EscapeDecoder.decode(scalars).scalars
        return isName(decoded.map { $0 == "\n" || $0 == "\r" ? " " : $0 }, compatibility: compatibility)
    }

    /// A letter, mark or number of any script, or a symbol whose compatibility form is ASCII
    /// letters and digits.
    private static func isLetterOrDigit(_ scalar: Unicode.Scalar, compatibility: CompatibilityText) -> Bool {
        if scalar.isASCII { return ASCII.isAlphanumeric(UInt8(scalar.value)) }
        if ScalarClass.isLetterOrNumber(scalar) { return true }
        let reading = compatibility.ascii(scalar)
        return !reading.isEmpty && reading.allSatisfy(ASCII.isAlphanumeric)
    }
}

