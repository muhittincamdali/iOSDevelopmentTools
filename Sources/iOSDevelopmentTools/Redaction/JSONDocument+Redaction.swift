extension JSONDocument {
    /// The replacements that redact the document. Every replacement covers one whole token or
    /// value and is valid JSON in its place, so the redacted document is still JSON:
    ///
    /// - The value of every member whose name hides it (see ``RedactionPolicy/hidesValue(ofKey:)``),
    ///   at any depth, inside
    ///   arrays and for every repetition of a name, becomes the string `"[REDACTED]"`, whatever its
    ///   type.
    /// - **Names written as values** (see ``WrittenName`` and ``NamingFields``). In an object with
    ///   a member whose value is a name that names a secret, the members that carry the value of
    ///   a pair are hidden whole, and, unless the name is a `name`, `id` or `type` that is only
    ///   written outside plain ASCII, the other members too: an object has no order. The
    ///   value of a member that holds a name (`name`, `key`, `field`, `label`, `type`, `header`,
    ///   `param`, `path`, `id`, `k`, `n`, or a member whose own name is not plain ASCII) is read by
    ///   the key rule, so a name that is not plain ASCII (`Şifre`, `ⓟⓘⓝ`, `🔑`, `Password:`)
    ///   names a secret, and so does an array or object there, which cannot be read as a name. Of
    ///   a `path`, every part between `/` is read that way, as JSON Patch (RFC 6902) and SCIM
    ///   PatchOp (RFC 7644) write it (`/user/password`, `/apiKeys/0`). The value of any other
    ///   member counts when it is a name whose words name a secret or cannot be read
    ///   (`{"ParameterKey":"DbPassword","ParameterValue":…}`): a string of letters, digits and
    ///   symbols whose compatibility form is a letter or digit, with spaces and `_`, `-`, `.` and
    ///   `/`, and any punctuation around it (`"Password:"`). The names of pairs stay (`name`,
    ///   `key`, `field`, `header`, `param`, `path`, `k`, `n` with a string), and so does an `op`
    ///   that names a JSON Patch or SCIM operation.
    /// - **Arrays.** The second element of a two-element array whose first is a string that the
    ///   key rule hides is hidden whole (`[["Authorization","…"]]`, as fetch headers and
    ///   `URLSearchParams` entries are written), and so is every element of an array after a
    ///   string that names a secret or cannot be read (`["password","…"]`).
    /// - Names and strings are free text: one in which anything is found is written again, escaped,
    ///   with the free-text rule applied to its decoded text, which may hold JSON again. They are
    ///   read with the document's ``nesting`` and the objects and arrays around them, so JSON in
    ///   them that goes past a limit of the budget hides the whole string.
    /// - A number that holds a card number or a long token becomes the string `"[REDACTED]"`.
    func secretSpans(using policy: RedactionPolicy, compatibility: CompatibilityText) -> [RedactionPolicy.Span] {
        var collector = SpanCollector(document: self, policy: policy, compatibility: compatibility)
        collector.collect(root, nesting: nesting)
        return collector.spans
    }

    /// Where the first value is that free text does not read on: the value of a member whose name,
    /// with its escapes decoded, `allows` does not take, or the second element of a two-element
    /// array whose first is a string that `allows` does not take (`["user","bob"]`, as fetch
    /// headers and `URLSearchParams` entries are written). The offset of its first scalar, or nil
    /// when every name is taken. The objects and arrays are walked with a stack of their own, not
    /// by recursion.
    func firstValue(notAllowedBy allows: ([Unicode.Scalar]) -> Bool) -> Int? {
        var first: Int?
        func note(_ node: Node) { first = min(first ?? node.range.lowerBound, node.range.lowerBound) }
        var pending = [root]
        while let node = pending.popLast() {
            switch node.value {
            case .object(let members):
                for member in members {
                    if allows(text(of: member.name)) { pending.append(member.value) } else { note(member.value) }
                }
            case .array(let elements):
                if elements.count == 2, case .string(let name) = elements[0].value, !allows(text(of: name)) {
                    note(elements[1])
                } else {
                    pending += elements
                }
            case .string, .number, .boolean, .null:
                break
            }
        }
        return first
    }

    /// Any value, quotes and brackets included, becomes the string `"[REDACTED]"`.
    static func hiding(_ node: Node) -> RedactionPolicy.Span {
        RedactionPolicy.Span(
            start: node.range.lowerBound, end: node.range.upperBound, replacement: "\"\(RedactionPolicy.replacement)\""
        )
    }

    /// The text as the content of a JSON string: `"`, `\` and control characters escaped.
    ///
    /// The UTF-8 is counted first and written into the string once, as
    /// ``RedactionPolicy/replacing(_:in:)`` writes its text. Appending each escape to a
    /// `String.UnicodeScalarView` copied what was already written every time, so a string full of
    /// quotes or line breaks took quadratic time: a megabyte of JSON written in one JSON string
    /// took two seconds, two megabytes six. Only ASCII bytes are escaped; the bytes of other
    /// scalars are copied as they are.
    static func escaped(_ text: String) -> String {
        var count = 0
        for byte in text.utf8 { count += escapedLength(byte) }
        guard count != text.utf8.count else { return text }
        return String(unsafeUninitializedCapacity: count) { buffer in
            var written = 0
            func write(_ byte: UInt8) {
                buffer[written] = byte
                written += 1
            }
            func write(escape letter: Unicode.Scalar) {
                write(UInt8(ascii: "\\"))
                write(UInt8(ascii: letter))
            }
            for byte in text.utf8 {
                switch byte {
                case UInt8(ascii: "\""), UInt8(ascii: "\\"):
                    write(UInt8(ascii: "\\"))
                    write(byte)
                case UInt8(ascii: "\n"): write(escape: "n")
                case UInt8(ascii: "\r"): write(escape: "r")
                case UInt8(ascii: "\t"): write(escape: "t")
                case ..<0x20:
                    for escape in "\\u00".utf8 { write(escape) }
                    write(hexDigits[Int(byte >> 4)])
                    write(hexDigits[Int(byte & 0x0F)])
                default:
                    write(byte)
                }
            }
            return written
        }
    }

    /// The bytes that the UTF-8 byte `byte` takes in a JSON string.
    private static func escapedLength(_ byte: UInt8) -> Int {
        switch byte {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "\n"), UInt8(ascii: "\r"), UInt8(ascii: "\t"): 2
        case ..<0x20: 6
        default: 1
        }
    }

    private static let hexDigits = Array("0123456789abcdef".utf8)
}

/// Walks a document once and collects its replacements.
private struct SpanCollector {
    let document: JSONDocument
    let policy: RedactionPolicy
    let compatibility: CompatibilityText
    private(set) var spans: [RedactionPolicy.Span] = []

    init(document: JSONDocument, policy: RedactionPolicy, compatibility: CompatibilityText) {
        self.document = document
        self.policy = policy
        self.compatibility = compatibility
    }

    private func text(of token: JSONDocument.StringToken) -> [Unicode.Scalar] { document.text(of: token) }

    /// Collects the replacements of a value inside the objects and arrays that `nesting` counts.
    /// The recursion follows the document, whose depth the reader bounded.
    mutating func collect(_ node: JSONDocument.Node, nesting: Nesting) {
        let inside = nesting.enteringContainer()
        switch node.value {
        case .object(let members):
            collectMembers(members, nesting: inside)
        case .array(let elements):
            let isHiddenPair = elements.count == 2 && namesPairValue(elements[0])
            var hidesRest = false
            for (index, element) in elements.enumerated() {
                guard !hidesRest, !(isHiddenPair && index == 1) else {
                    spans.append(JSONDocument.hiding(element))
                    continue
                }
                collect(element, nesting: inside)
                // The last element names nothing after it, so it is not read again as a name.
                if index + 1 < elements.count, case .string(let token) = element.value {
                    hidesRest = WrittenName.namesSecret(text(of: token), in: .element, policy: policy, compatibility: compatibility)
                }
            }
        case .string(let token):
            spans += stringSpans(token, role: .text, nesting: nesting)
        case .number:
            spans += numberSpans(node)
        case .boolean, .null:
            break
        }
    }

    /// The members of an object, inside the objects and arrays that `nesting` counts. A value is
    /// hidden whole when its name hides it or when another member names a secret.
    private mutating func collectMembers(_ objectMembers: [JSONDocument.Member], nesting: Nesting) {
        let naming = NamingFields(objectMembers.lazy.map(namingField), policy: policy, compatibility: compatibility)
        for (index, member) in objectMembers.enumerated() {
            spans += stringSpans(member.name, role: .name, nesting: nesting)
            if policy.hidesValue(ofKey: text(of: member.name)) || naming.hidesValue(at: index, of: namingField(member)) {
                spans.append(JSONDocument.hiding(member.value))
            } else {
                collect(member.value, nesting: nesting)
            }
        }
    }

    private func namingField(_ member: JSONDocument.Member) -> NamingFields.Field {
        let value: NamingFields.Value = switch member.value.value {
        case .string(let token): .string(text(of: token))
        case .object, .array: .structure
        case .number, .boolean, .null: .other
        }
        return (text(of: member.name), value)
    }

    /// Whether the first element of a two-element array names its second: a string that the key
    /// rule hides.
    private func namesPairValue(_ node: JSONDocument.Node) -> Bool {
        guard case .string(let token) = node.value else { return false }
        return WrittenName.namesSecret(text(of: token), in: .pairName, policy: policy, compatibility: compatibility)
    }

    /// A name or string whose decoded text the free-text rule changes is written again, escaped.
    private func stringSpans(_ token: JSONDocument.StringToken, role: FreeTextScanner.Role, nesting: Nesting) -> [RedactionPolicy.Span] {
        guard let redacted = policy.redactedText(text(of: token), compatibility: compatibility, role: role, nesting: nesting) else {
            return []
        }
        return [RedactionPolicy.Span(
            start: token.content.lowerBound, end: token.content.upperBound, replacement: JSONDocument.escaped(redacted))]
    }

    /// A number with a card number or a long token in it becomes the string `"[REDACTED]"`, since
    /// the replacement is not a number.
    private func numberSpans(_ node: JSONDocument.Node) -> [RedactionPolicy.Span] {
        let digits = Array(document.scalars[node.range])
        let found = RedactionPolicy.merged(policy.detectorSpans(in: NormalizedText(digits, compatibility: compatibility)))
        guard !found.isEmpty else { return [] }
        let replaced = RedactionPolicy.replacing(found, in: digits)
        return [RedactionPolicy.Span(
            start: node.range.lowerBound, end: node.range.upperBound, replacement: "\"\(JSONDocument.escaped(replaced))\"")]
    }
}
