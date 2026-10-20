/// Redaction of free text: log messages, error descriptions, kept header values, `text/plain`
/// bodies, and the strings, values and names that structured input holds.
extension RedactionPolicy {
    /// The text with its secrets replaced by ``replacement``.
    ///
    /// Free text has no grammar, so the rule does not try to tell where a value ends. It has one
    /// cut point: from the first trigger, everything to the end of the text is hidden, the lines
    /// below included. Hiding more than the secret is how the rule is meant to work. The text is
    /// read once, on a scanning copy without invisible characters (format characters, marks,
    /// default-ignorable code points such as U+3164, control characters), in Unicode compatibility
    /// form. The triggers are:
    ///
    /// - **A key that is not allowed.** In `key=value`, `key: value`, `key = value` and
    ///   `"key":"value"` the text is read on only after a key that is plain ASCII, names no secret
    ///   and is on ``allowedTextKeys`` (`status`, `method`, `path`, `duration_ms` and `count` by
    ///   default), written on the line of its separator, which is `=`, `:` or a run of them
    ///   (`:=`, `==`, `=>`) in ASCII. Any other key cuts the text at its value: `x=hunter2` becomes
    ///   `x=[REDACTED]` and `Error: …` becomes `Error: [REDACTED]`. A `:` between two digits, as in
    ///   `12:30`, is part of a time. JSON in the text follows the same rule member by member, and
    ///   a two-element array by its first string (`["user","bob"]`); the tag of an element is the
    ///   key of its text (`<user>bob</user>`).
    /// - **A secret name** (see ``secretNames``), with or without a separator, quoted or not:
    ///   `password=hunter2`, `password hunter2`, `"token":"…"`, `export AWS_SECRET_ACCESS_KEY …`.
    ///   The text is hidden from the value after the name. Words are read with punctuation inside
    ///   them (`pass~word`) and a space or `|` between two of them (`pass word`) read as a
    ///   separator, and one letter that has no ASCII form (`ɑ`, `ı`) read as any letter or,
    ///   between two letters, as none. This is a best effort: a
    ///   name disguised with two or more such letters and written without a separator
    ///   (`pɑsswoʀd hunter2`) is not found.
    /// - **A secret name written as a value.** After an allowed key that holds a name (`name=`,
    ///   `id=`, `type=`, … when the app allows them; never `path=`, the route of a request), a
    ///   name that names a secret, is not plain ASCII or is JSON: `name="password"`,
    ///   `label="Пароль"`, `name=["pin"]`. After a key that is not allowed, the key hides the name
    ///   already (`Content-Disposition: form-data; name="pin"`). In markup, a trigger inside a tag
    ///   hides the tag from its `<`, so the attributes written before the name are hidden too
    ///   (`<input value="…" name="password">`). The text of a property list's `<key>` element is
    ///   always hidden, since `key` is a secret name; the name of an end tag (`</password>`) names
    ///   no value after it.
    /// - **A key that is not plain ASCII** or has no letter or digit, or no key at all, before
    ///   `=` or `:` (`pаssword=…` with a Cyrillic `а`, `🔑=…`, `user[name]=…`, `=…`), and the last
    ///   words of a key that, read as one name, name a secret (`pass word=…`, `c v v: …`).
    /// - **A character outside the safe alphabet.** Letters, marks and digits of any script (also
    ///   `ｐ` and `²`), the ASCII space, tab, LF and CR, printable ASCII and a space such as U+00A0
    ///   are text. Every other character with text after it is a trigger, judged by its own
    ///   Unicode category: punctuation and symbols outside ASCII (`꞉`, `≔`, `→`, `·`, `—`, `’`,
    ///   `、`, `€`), also those that compatibility normalization reads as ASCII (`＝`, `…`, `‥`,
    ///   `™`, `№`, `ⓟ`), emoji, control characters, the line breaks VT, FF, U+0085, U+2028 and
    ///   U+2029, and private-use or unassigned code points. There is no list of look-alikes to
    ///   get around.
    /// - **An escape**, which is never decoded: `%XX`, `%uXXXX`, `&name;` (`&amp;`, `&lt;`), `&#…;`,
    ///   `\NNN`, `\xNN`, `\uNNNN` and `\u{…}`, and `\=`. The text is hidden from the escape on.
    /// - **A word longer than 256 characters**, which is no name or value that can be read.
    /// - **An ambiguous token**: a word that mixes scripts (`pаssword` with a Cyrillic `а`) or
    ///   holds an invisible character other than a mark (a zero-width space, `pa\u{115F}ssword`,
    ///   a control character), a quote or bracket that does not close, and JSON that does not
    ///   parse. The text is hidden from there.
    ///
    /// Text with no trigger is kept as it is (`status=200 method=GET path=/api/items`), except for
    /// what the value detectors find: JWTs, bearer tokens, long hex or Base64 strings, card
    /// numbers, IBANs and email addresses. JSON in the text (`{"…`, `[{…`, `["…`, `[[…`) is parsed
    /// with a JSON parser, within the limits of ``maximumJSONDepth`` and
    /// ``maximumNestedDocuments``, and redacted by the key rule of structured input before its
    /// members are compared with ``allowedTextKeys``; its strings are free text again, with this
    /// rule. URLs with a scheme and `//` are recorded as ``redact(url:)`` records them.
    public func redact(text: String) -> String {
        guard isEnabled else { return text }
        return redact(text, nesting: .text(length: text.unicodeScalars.count))
    }

    /// The findings in free text, in order and without overlaps: those of the JSON and URLs and of
    /// the value detectors, and the cut, from the first trigger to the end of the text. `nesting`
    /// says which documents the text is in; a text inside one whose JSON or URL goes past a limit
    /// is one finding.
    /// `allowedKeys` are the folded keys after which the text is read on; ``allowedTextKeys`` when
    /// nil.
    func textSpans(
        in scalars: [Unicode.Scalar], compatibility: CompatibilityText, role: FreeTextScanner.Role = .text, nesting: Nesting,
        allowedKeys: Set<String>? = nil
    ) -> [Span] {
        guard !scalars.isEmpty, !isQuietWord(scalars) else { return [] }
        return textSpans(
            in: scalars, text: NormalizedText(scalars, compatibility: compatibility), compatibility: compatibility, role: role, nesting: nesting,
            allowedKeys: allowedKeys)
    }

    /// ``textSpans(in:compatibility:role:nesting:)`` on a scanning copy that is already made.
    /// With `detectsInRegions` the value detectors also read the JSON and URLs in the text, which
    /// a path segment needs: a URL in one keeps its host, and a token in the host must still make
    /// the segment `:id`. A text inside a document found in the input that the reading budget no
    /// longer covers (see ``ReadingBudget``) is one finding.
    func textSpans(
        in scalars: [Unicode.Scalar], text: NormalizedText, compatibility: CompatibilityText, role: FreeTextScanner.Role = .text,
        nesting: Nesting, detectsInRegions: Bool = false, allowedKeys: Set<String>? = nil
    ) -> [Span] {
        guard !scalars.isEmpty else { return [] }
        let whole = [Span(start: 0, end: scalars.count, replacement: Self.replacement)]
        guard scalars.count <= Self.maximumTextLength, nesting.reads(scalars.count) else { return whole }
        var scanner = FreeTextScanner(
            source: scalars, text: text, policy: self, compatibility: compatibility, role: role, nesting: nesting,
            allowedKeys: allowedKeys ?? allowedTextKeys)
        scanner.run()
        if scanner.hidesWholeText { return whole }
        let cut = scanner.cut.flatMap { $0 < scalars.count ? [Span(start: $0, end: scalars.count, replacement: Self.replacement)] : nil } ?? []
        // JSON and URLs were redacted by their own rules; the detectors do not read them again.
        // A finding that runs into the cut is merged with it.
        let regions = scanner.regions
        var found = detectorSpans(in: text)
        if !regions.isEmpty, !detectsInRegions {
            let crossing = Self.crossing(found, regions)
            found = detectorSpans(in: NormalizedText(scalars, compatibility: compatibility, masked: regions))
            found += crossing
        }
        found += scanner.spans
        found += cut
        return Self.merged(found)
    }

    /// The findings that run over the edge of a JSON or URL region, hidden whole. A URL ends
    /// before the punctuation that ends a sentence, so `…?q=eyJ….eyJ….` keeps the dot of an
    /// unsigned token outside it, and a card number may start in a query and go on after it:
    /// neither the region nor the text outside it holds the finding, but the text as a whole does,
    /// as a body or a string holding the same text would.
    static func crossing(_ spans: [Span], _ regions: [Range<Int>]) -> [Span] {
        // Regions do not overlap: the scanner records each after the one before.
        let regions = regions.sorted { $0.lowerBound < $1.lowerBound }
        return spans.compactMap { span in
            var low = 0
            var high = regions.count
            while low < high {
                let middle = (low + high) / 2
                if regions[middle].lowerBound < span.end { low = middle + 1 } else { high = middle }
            }
            guard low > 0 else { return nil }
            let last = regions[low - 1]
            let crosses = last.lowerBound > span.start || (last.upperBound > span.start && span.end > last.upperBound)
            return crosses ? Span(start: span.start, end: span.end, replacement: replacement) : nil
        }
    }

    /// The longest text that is read: one of more scalars than 32 bits count is hidden whole (see
    /// ``ScalarOffsets``).
    static let maximumTextLength = Int(UInt32.max)

    /// The longest text ``isQuietWord(_:)`` takes: the shortest card number has 13 digits, an
    /// IBAN 15 characters and a long token 32.
    static let quietWordLength = 12

    /// Whether a text is one word of at most ``quietWordLength`` ASCII letters and digits with no
    /// secret word in it, such as most JSON strings, path segments and query names. No rule and
    /// no detector finds anything in such a word, so it is not scanned; reading every one of them
    /// took most of the time of a JSON array of short strings and of a URL of many segments.
    func isQuietWord(_ scalars: [Unicode.Scalar]) -> Bool {
        guard scalars.count <= Self.quietWordLength else { return false }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(scalars.count)
        for scalar in scalars {
            guard scalar.isASCII, ASCII.isAlphanumeric(UInt8(scalar.value)) else { return false }
            bytes.append(UInt8(scalar.value))
        }
        return PlainName(bytes: bytes, maximumLength: nil)?.namesSecret(in: secretNameTable) == false
    }

    /// The findings of the value detectors: the password in `user:password@host`, bearer tokens,
    /// JWTs, email addresses, card numbers, IBANs and long hex or Base64 strings.
    func detectorSpans(in text: NormalizedText) -> [Span] {
        // Joined one detector at a time, so that a text of many findings holds one list of them
        // and the findings of one detector at most.
        var spans: [Span] = []
        for detect in Self.detectors {
            let found = detect(text)()
            if spans.isEmpty { spans = found } else if !found.isEmpty { spans += found }
        }
        return spans
    }

    private static let detectors: [@Sendable (NormalizedText) -> () -> [Span]] = [
        NormalizedText.userInfoPasswordSpans, NormalizedText.bearerSpans, NormalizedText.jsonWebTokenSpans, NormalizedText.emailSpans,
        NormalizedText.cardSpans, NormalizedText.ibanSpans, NormalizedText.longTokenSpans,
    ]

    /// The text redacted as free text; nil when nothing changed.
    func redactedText(
        _ scalars: [Unicode.Scalar], compatibility: CompatibilityText, role: FreeTextScanner.Role = .text, nesting: Nesting
    ) -> String? {
        let spans = textSpans(in: scalars, compatibility: compatibility, role: role, nesting: nesting)
        guard !spans.isEmpty else { return nil }
        return Self.replacing(spans, in: scalars)
    }

    /// A text inside a document (a form value, a query value, a header value) or passed in on its
    /// own, redacted as free text with the given nesting.
    func redact(_ text: String, nesting: Nesting) -> String {
        let scalars = Array(text.unicodeScalars)
        let spans = textSpans(in: scalars, compatibility: CompatibilityText(), nesting: nesting)
        return spans.isEmpty ? text : Self.replacing(spans, in: scalars)
    }

    /// Whether free text is read on after the key `name`: it is plain ASCII, names no secret and
    /// is on `keys` once folded.
    func allowsTextKey(_ name: some Collection<Unicode.Scalar>, in keys: Set<String>) -> Bool {
        guard let fold = allowableFold(name) else { return false }
        return keys.contains(fold)
    }

    /// A key that is written out (a form or multipart field name, a query parameter name) read as
    /// free text in the ``FreeTextScanner/Role/name`` role.
    func redactedName(_ name: String, nesting: Nesting) -> String {
        redactedText(Array(name.unicodeScalars), compatibility: CompatibilityText(), role: .name, nesting: nesting) ?? name
    }
}
