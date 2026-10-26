extension JSONDocument {
    /// The replacements that redact the document. Every replacement covers one whole token or
    /// value and is valid JSON in its place, so the redacted document is still JSON:
    ///
    /// - The value of every member whose name hides it (see ``FieldName``), at any depth, inside
    ///   arrays and for every repetition of a name, becomes the string `"[REDACTED]"`, whatever its
    ///   type.
    /// - **Names written as values** (see ``WrittenName``). In an object with a member whose value
    ///   is a name that names a secret, the values of the other members are hidden whole, whatever
    ///   their names: an object has no order, so what belongs to the name cannot be told. The
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
    /// - A number that holds a card number or a long token becomes the string `"[REDACTED]"`; a
    ///   number with an exponent is read as the decimal it stands for (`4.111111111111111E15`).
    func secretSpans(using policy: RedactionPolicy, compatibility: CompatibilityText) -> [RedactionPolicy.Span] {
        var spans: [RedactionPolicy.Span] = []
        collect(root, nesting: nesting, into: &spans, policy: policy, compatibility: compatibility)
        return spans
    }

    /// Collects the replacements of a value inside the objects and arrays that `nesting` counts.
    /// The recursion follows the document, whose depth the reader bounded.
    private func collect(
        _ node: Node, nesting: Nesting, into spans: inout [RedactionPolicy.Span], policy: RedactionPolicy,
        compatibility: CompatibilityText
    ) {
        let inside = nesting.enteringContainer()
        switch node.value {
        case .object(let members):
            collectMembers(members, nesting: inside, into: &spans, policy: policy, compatibility: compatibility)
        case .array(let elements):
            let isHiddenPair = elements.count == 2 && namesPairValue(elements[0], compatibility: compatibility)
            var hidesRest = false
            for (index, element) in elements.enumerated() {
                guard !hidesRest, !(isHiddenPair && index == 1) else {
                    spans.append(Self.hiding(element))
                    continue
                }
                collect(element, nesting: inside, into: &spans, policy: policy, compatibility: compatibility)
                // The last element names nothing after it, so it is not read again as a name.
                if index + 1 < elements.count, case .string(let token) = element.value {
                    hidesRest = WrittenName.namesSecret(text(of: token), in: .element, compatibility: compatibility)
                }
            }
        case .string(let token):
            spans += stringSpans(token, role: .text, nesting: nesting, policy: policy, compatibility: compatibility)
        case .number:
            spans += numberSpans(node, policy: policy, compatibility: compatibility)
        case .boolean, .null:
            break
        }
    }

    /// The members of an object, inside the objects and arrays that `nesting` counts. A value is
    /// hidden whole when its name hides it or when another member names a secret.
    private func collectMembers(
        _ members: ContiguousArray<Member>, nesting: Nesting, into spans: inout [RedactionPolicy.Span], policy: RedactionPolicy,
        compatibility: CompatibilityText
    ) {
        let naming = NamingFields(members.lazy.map(namingField), compatibility: compatibility)
        for (index, member) in members.enumerated() {
            spans += stringSpans(member.name, role: .name, nesting: nesting, policy: policy, compatibility: compatibility)
            if policy.hidesValue(ofKey: text(of: member.name)) || naming.hidesValue(at: index, of: namingField(member)) {
                spans.append(Self.hiding(member.value))
            } else {
                collect(member.value, nesting: nesting, into: &spans, policy: policy, compatibility: compatibility)
            }
        }
    }

    private func namingField(_ member: Member) -> NamingFields.Field {
        let value: NamingFields.Value = switch member.value.value {
        case .string(let token): .string(text(of: token))
        case .object, .array: .structure
        case .number, .boolean, .null: .other
        }
        return (text(of: member.name), value)
    }

    /// Whether the first element of a two-element array names its second: a string that the key
    /// rule hides.
    private func namesPairValue(_ node: Node, compatibility: CompatibilityText) -> Bool {
        guard case .string(let token) = node.value else { return false }
        return WrittenName.namesSecret(text(of: token), in: .pairName, compatibility: compatibility)
    }

    /// Where the first key in the text is that `matches`, with its escapes decoded: the offset of
    /// its opening quote, or nil when no key does. A key is the name of a member and the first
    /// element of a two-element array that is a string (`["user","…"]`, `[["X-User","…"]]`),
    /// whose second element is its value. The objects and arrays are walked with a stack of their
    /// own, not by recursion.
    func firstKey(where matches: ([Unicode.Scalar]) -> Bool) -> Int? {
        var first: Int?
        func found(_ start: Int) { first = min(first ?? start, start) }
        var pending = [root]
        while let node = pending.popLast() {
            switch node.value {
            case .object(let members):
                for member in members {
                    if matches(text(of: member.name)) {
                        found(member.name.content.lowerBound - 1)
                    } else {
                        pending.append(member.value)
                    }
                }
            case .array(let elements):
                if elements.count == 2, case .string(let key) = elements[0].value, matches(text(of: key)) {
                    found(elements[0].range.lowerBound)
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
    private static func hiding(_ node: Node) -> RedactionPolicy.Span {
        RedactionPolicy.Span(
            start: node.range.lowerBound, end: node.range.upperBound, kind: .secretFields, replacement: "\"\(RedactionPolicy.replacement)\""
        )
    }

    /// A name or string whose decoded text the free-text rule changes is written again, escaped.
    private func stringSpans(
        _ token: StringToken, role: FreeTextScanner.Role, nesting: Nesting, policy: RedactionPolicy, compatibility: CompatibilityText
    ) -> [RedactionPolicy.Span] {
        guard let (redacted, kind) = policy.redactedText(text(of: token), compatibility: compatibility, role: role, nesting: nesting) else {
            return []
        }
        return [RedactionPolicy.Span(start: token.content.lowerBound, end: token.content.upperBound, kind: kind, replacement: Self.escaped(redacted))]
    }

    /// A number with a card number or a long token in it becomes a string, since ``RedactionPolicy/replacement``
    /// is not a number. A number with an exponent is read as the decimal it stands for (see
    /// ``JSONNumber``), and what is found there hides it whole: `4.111111111111111E15` and
    /// `4111111111111111e0` become `"[REDACTED]"`. A number without one is read as written, and
    /// only what is found is replaced: `-4111111111111111` becomes `"-[REDACTED]"`.
    private func numberSpans(_ node: Node, policy: RedactionPolicy, compatibility: CompatibilityText) -> [RedactionPolicy.Span] {
        let digits = Array(scalars[node.range])
        if let plain = JSONNumber.plainDecimal(digits) {
            let found = policy.detectorSpans(in: NormalizedText(plain, compatibility: compatibility))
            if !found.isEmpty {
                let kind = found.reduce(into: RedactionPolicy.Kinds()) { $0.formUnion($1.kind) }
                let replacement = "\"\(RedactionPolicy.replacement)\""
                return [RedactionPolicy.Span(start: node.range.lowerBound, end: node.range.upperBound, kind: kind, replacement: replacement)]
            }
        }
        let found = RedactionPolicy.merged(policy.detectorSpans(in: NormalizedText(digits, compatibility: compatibility)))
        guard !found.isEmpty else { return [] }
        let kind = found.reduce(into: RedactionPolicy.Kinds()) { $0.formUnion($1.kind) }
        let masked = RedactionPolicy.replacing(found, in: digits)
        return [RedactionPolicy.Span(start: node.range.lowerBound, end: node.range.upperBound, kind: kind, replacement: "\"\(Self.escaped(masked))\"")]
    }

    /// The text as the content of a JSON string. The length of the output is counted first and
    /// the output written once: appending escapes to a `String.UnicodeScalarView` one at a time
    /// copied what was written before them, and a megabyte of quotes took two seconds.
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
