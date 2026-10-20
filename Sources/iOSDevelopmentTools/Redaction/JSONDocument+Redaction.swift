extension JSONDocument {
    /// Which members of the document's objects keep their values.
    enum MemberRule {
        /// Structured input (a body, a form or query value read as JSON): a member keeps its value
        /// unless its name hides it by the key rule (see ``RedactionPolicy/hidesValue(ofKey:)``).
        case keyRule
        /// JSON written in free text, where every member is a pair of free text: a member keeps
        /// its value only when its name is plain ASCII, names no secret and is on
        /// ``RedactionPolicy/allowedTextKeys``.
        case allowedTextKeys
    }

    /// The replacements that redact the document. Every replacement covers one whole token or
    /// value and is valid JSON in its place, so the redacted document is still JSON:
    ///
    /// - The value of every member whose name hides it (see `members`), at any depth, inside
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
    /// - A number that holds a card number or a long token becomes the string `"[REDACTED]"`.
    func secretSpans(using policy: RedactionPolicy, members: MemberRule, compatibility: CompatibilityText) -> [RedactionPolicy.Span] {
        var collector = SpanCollector(document: self, policy: policy, members: members, compatibility: compatibility)
        collector.collect(root, nesting: nesting)
        return collector.spans
    }

    /// Any value, quotes and brackets included, becomes the string `"[REDACTED]"`.
    static func hiding(_ node: Node) -> RedactionPolicy.Span {
        RedactionPolicy.Span(
            start: node.range.lowerBound, end: node.range.upperBound, isFinding: true, replacement: "\"\(RedactionPolicy.replacement)\""
        )
    }

    /// The text as the content of a JSON string.
    static func escaped(_ text: String) -> String {
        var output = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": output.append(contentsOf: "\\\"".unicodeScalars)
            case "\\": output.append(contentsOf: "\\\\".unicodeScalars)
            case "\n": output.append(contentsOf: "\\n".unicodeScalars)
            case "\r": output.append(contentsOf: "\\r".unicodeScalars)
            case "\t": output.append(contentsOf: "\\t".unicodeScalars)
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                output.append(contentsOf: ("\\u" + String(repeating: "0", count: 4 - hex.count) + hex).unicodeScalars)
            default: output.append(scalar)
            }
        }
        return String(output)
    }
}

/// Walks a document once and collects its replacements.
private struct SpanCollector {
    let document: JSONDocument
    let policy: RedactionPolicy
    let members: JSONDocument.MemberRule
    let compatibility: CompatibilityText
    private(set) var spans: [RedactionPolicy.Span] = []

    init(document: JSONDocument, policy: RedactionPolicy, members: JSONDocument.MemberRule, compatibility: CompatibilityText) {
        self.document = document
        self.policy = policy
        self.members = members
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
        let naming = namingFields(objectMembers)
        for (index, member) in objectMembers.enumerated() {
            spans += stringSpans(member.name, role: .name, nesting: nesting)
            if hidesValue(ofName: text(of: member.name)) || naming.hidesValue(at: index) {
                spans.append(JSONDocument.hiding(member.value))
            } else {
                collect(member.value, nesting: nesting)
            }
        }
    }

    private func hidesValue(ofName name: [Unicode.Scalar]) -> Bool {
        switch members {
        case .keyRule: policy.hidesValue(ofKey: name)
        case .allowedTextKeys: policy.allowableFold(name).map { !policy.allowedTextKeys.contains($0) } ?? true
        }
    }

    private func namingFields(_ objectMembers: [JSONDocument.Member]) -> NamingFields {
        NamingFields(objectMembers.map { member in
            let value: NamingFields.Value = switch member.value.value {
            case .string(let token): .string(text(of: token))
            case .object, .array: .structure
            case .number, .boolean, .null: .other
            }
            return (text(of: member.name), value)
        }, policy: policy, compatibility: compatibility)
    }

    /// Whether the first element of a two-element array names its second: a string that the key
    /// rule hides.
    private func namesPairValue(_ node: JSONDocument.Node) -> Bool {
        guard case .string(let token) = node.value else { return false }
        return WrittenName.namesSecret(text(of: token), in: .pairName, policy: policy, compatibility: compatibility)
    }

    /// A name or string whose decoded text the free-text rule changes is written again, escaped.
    private func stringSpans(_ token: JSONDocument.StringToken, role: FreeTextScanner.Role, nesting: Nesting) -> [RedactionPolicy.Span] {
        guard let (redacted, hidesSomething) = policy.redactedText(text(of: token), compatibility: compatibility, role: role, nesting: nesting) else {
            return []
        }
        return [RedactionPolicy.Span(
            start: token.content.lowerBound, end: token.content.upperBound, isFinding: hidesSomething, replacement: JSONDocument.escaped(redacted))]
    }

    /// A number with a card number or a long token in it becomes the string `"[REDACTED]"`, since
    /// the replacement is not a number.
    private func numberSpans(_ node: JSONDocument.Node) -> [RedactionPolicy.Span] {
        let digits = Array(document.scalars[node.range])
        let found = RedactionPolicy.merged(policy.detectorSpans(in: NormalizedText(digits, compatibility: compatibility)))
        guard !found.isEmpty else { return [] }
        let replaced = RedactionPolicy.replacing(found, in: digits)
        return [RedactionPolicy.Span(
            start: node.range.lowerBound, end: node.range.upperBound, isFinding: true, replacement: "\"\(JSONDocument.escaped(replaced))\"")]
    }
}
