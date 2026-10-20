/// Redaction of free text: log messages, error descriptions, kept header values, `text/plain`
/// bodies, and the strings, values and names that structured input holds.
extension RedactionPolicy {
    /// The text with its secrets replaced by ``replacement``.
    ///
    /// Free text has no grammar, so its keys are read the other way round from those of
    /// structured input, with an allowlist. The text is read on a scanning copy without invisible
    /// characters (format characters, marks, default-ignorable code points such as U+3164, control
    /// characters) and in Unicode compatibility form:
    ///
    /// - **Pairs.** In `key=value`, `key: value`, `key = value` and `"key":"value"` the value is
    ///   kept only when the key is plain ASCII and on ``allowedTextKeys``. Any other value is
    ///   replaced: a quoted one (`"`, `'` or a backtick) up to its closing quote, a JSON object or
    ///   array whole, anything else with the rest of its line, because where it ends cannot be
    ///   told. The separators are `=` and `:`, also as characters whose compatibility form is one
    ///   (`＝`, `：`, `︓`) and as escapes (`%3D`, `&#61;`); a `:` between two digits, as in
    ///   `12:30`, is part of a time. Punctuation and math symbols outside ASCII (`≔`, `꞉`, `→`,
    ///   `·`) separate too, where they follow other text.
    /// - **Secret names without a separator.** A word that holds a secret name hides the rest of
    ///   its line: `password hunter2`, `PIN 1234`, `export AWS_SECRET_ACCESS_KEY …`. Words are read
    ///   after their escapes are decoded, with punctuation inside them (`pass~word`) and a space or
    ///   `|` between two of them (`pass word`) read as a separator, and one letter that has no
    ///   ASCII form (`ɑ`, `ı`) read as any letter or, between two letters, as none (`passꞏword`).
    ///   This is a best effort: a name disguised with two or more such letters and written
    ///   without a separator (`pɑsswoʀd hunter2`) is not found.
    /// - **Ambiguity.** A word that mixes scripts (`pаssword` with a Cyrillic `а`) or holds an
    ///   invisible character other than a mark (`pa\u{115F}ssword`, a zero-width space, a control
    ///   character) hides itself and the rest of its line.
    /// - **Values that go on.** A quote that does not close on its line hides the lines up to the
    ///   one where it closes, and that line whole. After a value hidden to the end of its line, the
    ///   lines indented more and the line after a trailing `\` are hidden; so is the next line with
    ///   text when nothing but punctuation followed the name, the line ends open (`(`, `:`, `<key>`,
    ///   `"""`) or it ends at a break other than LF and CRLF.
    /// - **Secret names written as values.** A quoted value that names a secret or cannot be read
    ///   (`name="password"`, `<string name="api_key">`) hides the rest of its line after the
    ///   closing quote. After a key that holds a name (`name=`, `key=`, `label=`, `id=`, … but not
    ///   `path=`, the route of a request) a name that is not plain ASCII counts as secret, as in
    ///   JSON (`label="Пароль"`), and so does JSON there (`name=["pin"]`), to the end of the line
    ///   where it closes when it spans lines. In XML and HTML the other attribute values of its
    ///   start tag are hidden too, and the lines below up to the end of the element and the rest of
    ///   the line where it ends; a secret name in an element's text (`<key>password</key>`) names
    ///   the element after it, also on the lines below, as a property list writes them. An element
    ///   that holds nothing (`<string/>`, `<string></string>`) holds no value, so the text after
    ///   it, or the next line with text that is not markup, is hidden too. A name that is plain
    ///   and not secret keeps what follows it.
    /// - **Embedded JSON.** JSON in a line (`{"…`, `[{…`, `["…`, `[[…`) is parsed with a JSON
    ///   parser, within the limits of ``maximumJSONDepth`` and ``maximumNestedDocuments``. Its
    ///   members are pairs too: a member keeps its value only when its name is plain ASCII and on
    ///   ``allowedTextKeys``; every other value is hidden whole, whatever its type. JSON that does
    ///   not parse hides the rest of the line, and the lines below until its brackets close.
    /// - **URLs** with a scheme and `//` are recorded as ``redact(url:)`` records them.
    /// - **Values** are scanned for JWTs, bearer tokens, long hex or Base64 strings, card numbers,
    ///   IBANs and email addresses everywhere.
    ///
    /// U+2028, U+2029, U+0085, vertical tab and form feed end a line and are written as line feeds,
    /// so the result breaks lines where the rule did; CR and CRLF end a line too and are kept.
    public func redact(text: String) -> String {
        guard isEnabled else { return text }
        return redact(text, nesting: .text(length: text.unicodeScalars.count))
    }

    /// The findings in free text, in order and without overlaps. `nesting` says which documents
    /// the text is in; a text inside one whose JSON or URL goes past a limit is one finding.
    func textSpans(in scalars: [Unicode.Scalar], compatibility: CompatibilityText, role: FreeTextScanner.Role = .text, nesting: Nesting) -> [Span] {
        guard !scalars.isEmpty, !isQuietWord(scalars) else { return [] }
        return textSpans(in: scalars, text: NormalizedText(scalars, compatibility: compatibility), compatibility: compatibility, role: role, nesting: nesting)
    }

    /// ``textSpans(in:compatibility:role:nesting:)`` on a scanning copy that is already made.
    /// With `detectsInRegions` the value detectors also read the JSON and URLs in the text, which
    /// a path segment needs: a URL in one keeps its host, and a token in the host must still make
    /// the segment `:id`. A text inside a document found in the input that the reading budget no
    /// longer covers (see ``ReadingBudget``) is one finding.
    func textSpans(
        in scalars: [Unicode.Scalar], text: NormalizedText, compatibility: CompatibilityText, role: FreeTextScanner.Role = .text,
        nesting: Nesting, detectsInRegions: Bool = false
    ) -> [Span] {
        guard !scalars.isEmpty else { return [] }
        let whole = [Span(start: 0, end: scalars.count, isFinding: true, replacement: Self.replacement)]
        guard nesting.reads(scalars.count) else { return whole }
        var scanner = FreeTextScanner(source: scalars, text: text, policy: self, compatibility: compatibility, role: role, nesting: nesting)
        scanner.run()
        if scanner.hidesWholeText { return whole }
        // JSON and URLs were redacted by their own rules; the detectors do not read them again.
        let regions = scanner.regions
        let folds = Self.lineSeparatorFolds(in: scalars, outside: regions)
        guard !regions.isEmpty, !detectsInRegions else { return Self.merged(scanner.spans + detectorSpans(in: text) + folds) }
        let outside = detectorSpans(in: NormalizedText(scalars, compatibility: compatibility, masked: regions))
        return Self.merged(scanner.spans + outside + Self.crossing(detectorSpans(in: text), regions) + folds)
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
            return crosses ? Span(start: span.start, end: span.end, isFinding: true, replacement: replacement) : nil
        }
    }

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
        text.userInfoPasswordSpans() + text.bearerSpans() + text.jsonWebTokenSpans() + text.emailSpans() + text.cardSpans()
            + text.ibanSpans() + text.longTokenSpans()
    }

    /// The text redacted as free text, and whether anything was hidden in it (rather than only
    /// line separators written as line feeds); nil when nothing changed.
    func redactedText(
        _ scalars: [Unicode.Scalar], compatibility: CompatibilityText, role: FreeTextScanner.Role = .text, nesting: Nesting
    ) -> (text: String, hidesSomething: Bool)? {
        let spans = textSpans(in: scalars, compatibility: compatibility, role: role, nesting: nesting)
        guard !spans.isEmpty else { return nil }
        return (Self.replacing(spans, in: scalars), spans.contains(where: \.isFinding))
    }

    /// A text inside a document (a form value, a query value, a header value) or passed in on its
    /// own, redacted as free text with the given nesting.
    func redact(_ text: String, nesting: Nesting) -> String {
        let scalars = Array(text.unicodeScalars)
        let spans = textSpans(in: scalars, compatibility: CompatibilityText(), nesting: nesting)
        return spans.isEmpty ? text : Self.replacing(spans, in: scalars)
    }

    /// A key that is written out (a form or multipart field name, a query parameter name) read as
    /// free text in the ``FreeTextScanner/Role/name`` role.
    func redactedName(_ name: String, nesting: Nesting) -> String {
        redactedText(Array(name.unicodeScalars), compatibility: CompatibilityText(), role: .name, nesting: nesting)?.text ?? name
    }

    /// U+2028, U+2029, U+0085, vertical tab and form feed, written as line feeds, since the
    /// free-text rule ends a line at them. Inside JSON they are kept: a JSON string may hold them.
    private static func lineSeparatorFolds(in scalars: [Unicode.Scalar], outside regions: [Range<Int>]) -> [Span] {
        var folds: [Span] = []
        let sortedRegions = regions.sorted { $0.lowerBound < $1.lowerBound }
        var regionIndex = 0
        for (offset, scalar) in scalars.enumerated() where foldedLineSeparators.contains(scalar) {
            while regionIndex < sortedRegions.count, sortedRegions[regionIndex].upperBound <= offset { regionIndex += 1 }
            if regionIndex < sortedRegions.count, sortedRegions[regionIndex].contains(offset) { continue }
            folds.append(Span(start: offset, end: offset + 1, isFinding: false, replacement: "\n"))
        }
        return folds
    }

    private static let foldedLineSeparators: Set<Unicode.Scalar> = ["\u{0B}", "\u{0C}", "\u{85}", "\u{2028}", "\u{2029}"]
}
