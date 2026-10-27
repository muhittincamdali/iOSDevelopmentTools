/// Redaction of free text: kept header values, `text/plain` bodies, text you pass to
/// ``RedactionPolicy/redact(text:)``, and the strings, values and names that structured input holds.
extension RedactionPolicy {
    /// The text with its secrets replaced by ``replacement``.
    ///
    /// The text is read as free text, which has no grammar, so it follows one rule: **the first
    /// trigger hides everything after it, to the end of the text** — not only the rest of its
    /// line. This hides more than it has to on purpose. A text without a trigger is written as it
    /// is, apart from the card numbers, IBANs, email addresses and tokens in it, which the value
    /// detectors find (see ``RedactionPolicy``).
    ///
    /// ```swift
    /// policy.redact(text: "GET /items status=200 duration_ms=12")    // kept as it is
    /// policy.redact(text: "login user=bob status=401\nretry 2")      // "login user=[REDACTED]"
    /// policy.redact(text: "password hunter2")                         // "password [REDACTED]"
    /// ```
    ///
    /// Six rules decide where the text is cut, and no list of variants is kept for any of them:
    ///
    /// - **A safe alphabet.** The text is read only as far as it is written in letters, marks and
    ///   digits of any script (the Unicode categories L, M and N), the ASCII space, tab, line feed
    ///   and carriage return, and printable ASCII. The first character outside it cuts the text
    ///   there: punctuation, a symbol or a space outside ASCII (`꞉`, `≔`, `→`, `·`, `＝`, `—`, `€`,
    ///   an emoji, U+00A0, U+2028), a control or format character (a zero-width space, `DEL`) and
    ///   every default-ignorable code point (U+3164). So does a letter or number whose
    ///   compatibility form, which is what the text is read as, is not in the alphabet (`🄁` is
    ///   `0,`, `⑴` is `(1)`, `½` is `1⁄2`). A modifier letter (`ː`, `ー`) is in the alphabet only
    ///   after a letter or digit outside ASCII, as in Japanese or Thai.
    /// - **Escapes.** An escape is never decoded: one that can stand for any character cuts the
    ///   text at the start of the word it is in — `%3D`, `%u003D`, `&#61;`, `&colon;`, `&amp;`, and
    ///   `&` before a letter unless it starts the name of a field before `=` (`&count=3`). In free
    ///   text every backslash escape cuts the text: a backslash does, whatever follows it, unless
    ///   an ASCII space, tab or line break or the end of the text does, so no list of its forms is
    ///   kept (`\075`, `\x3D`, `\x{73}`, `\o{163}`, `\N{…}`, `\q`; `login pa\x{73}sword hunter2`
    ///   keeps `login `). A Windows path is hidden from its first backslash on, by design.
    /// - **Opaque words.** A word longer than 256 characters cuts the text where it starts: it
    ///   cannot be read as a name.
    /// - **The key rule, in every shape.** In `key=value`, `key: value`, `key = value` and
    ///   `"key":"value"` the text is read on only after a key that is plain ASCII and on
    ///   ``allowedTextKeys`` (`status`, `method`, `path`, `duration_ms` and `count` by default).
    ///   Any other key cuts the text at its value, and so does a separator with no key before it
    ///   or a key on the line before its separator. A key in quotes of any kind — `"…":`, `'…'=`
    ///   or in backticks, a `'` opening a quote only at the start of a word — that is not allowed
    ///   cuts the text at its opening quote, so nothing written in the quotes shows (`cache miss
    ///   for "session Qz9Wk7rX": refetching` and `{'status': 200, 'last status': 'x'}` keep
    ///   `cache miss for ` and `{'status': 200, `); a key with a space in it is never allowed. A
    ///   quote glued to the word before it starts no quoted key: the text is cut where that word
    ///   starts (`x"status": 200` keeps nothing).
    ///   The separators are `=` and `:` and runs of
    ///   them (`:=`, `==`, `=>`); a `:` between two digits is part of a number only when both
    ///   sides have the whole shape of one — a time, a date and time, an address and its port or a
    ///   line and column, as in `12:30:45`, `2026-10-19T12:30:45Z`, `10.0.0.1:8080` and `42:10`,
    ///   and then the end of the word. A word before the `:` of another shape (`1.234:56`,
    ///   `1-1-1:2345`), a letter after the digits (`7:9hunter2` cuts at `9hunter2`) or right after
    ///   the punctuation that follows them (`12:30,hunter2`), five or more digits right after the
    ///   `:` (`1:482913`) and a key that ends in digits (`user1:2345`) make it a separator. JSON in the text follows
    ///   the same rule member by member, a member name that is not allowed cutting it at its
    ///   opening quote, and the first string of a two-element array is a key too
    ///   (`["user","bob"]` cuts at `"user"`).
    /// - **Markup.** In free text the first markup tag cuts the text: markup is never parsed. A
    ///   `<` is a comparison only before an ASCII space, tab or line break, an ASCII digit, `=` or
    ///   the end of the text (`a < b`, `1<2`, `<3`); before anything else it cuts the text there,
    ///   whatever follows — a letter of any script, `_`, `:`, `/`, `!`, `?`, other punctuation or
    ///   a digit outside ASCII (`<user>`, `<_id>`, `</a>`, `<!-- … -->`, `<![CDATA[…]]>`,
    ///   `<?xml …?>`, `<०>`, `x << 1`); no tag is allowed. `login <user>bob</user>` keeps
    ///   `login `.
    /// - **Secret names.** A word that holds a secret name cuts the text after the name, with or
    ///   without a separator: `password hunter2`, `PIN 1234`, `export AWS_SECRET_ACCESS_KEY …`.
    ///   Punctuation inside a word (`pass~word`) and a space or `|` between two words
    ///   (`pass word`) are read as a separator. A word is compared by its ASCII skeleton, with
    ///   one wildcard rule: a letter, mark or number outside ASCII that has no ASCII form (`ꞏ`,
    ///   `ı`, `ɑ`, a combining mark such as U+0366, `〇`, a decimal digit of another script such as
    ///   the Myanmar `၀`) counts as nothing or as any one letter. It is left out, and what remains
    ///   is compared with the secret names, a plural `s` included (`piꞏn`, `tokeın`, `tokenꞏs`,
    ///   `keyıs`); a name also counts with one of its letters missing where such a character
    ///   stands, so one put in place of a letter is found (`pɑssword`, `user_pın`, `tͦken`,
    ///   `passw〇rd`, `t၀ken`). A word of another language that reads as a name this way hides
    ///   what follows it (Turkish `yapın` reads as `pin`), on purpose. A name written
    ///   without a separator with two or more of its letters replaced so (`pɑsswoʀd hunter2`) is
    ///   not found: that is deliberate disguise.
    ///   After an allowed key that holds a name (`id=`, `type=`, … but not `path=`, the route of a
    ///   request), a secret name or one that is not plain ASCII cuts the text after it, as in JSON
    ///   (`type="Пароль"`), and so does JSON there.
    ///
    /// A word that mixes scripts (`pаssword` with a Cyrillic `а`) cuts the text where it starts.
    /// A quote (`"`, a backtick, or `'` at the start of a word) that does not close on its line,
    /// or before the first character outside the safe alphabet, cuts the text at the quote, so a
    /// quoted key with a line break in it shows nothing (`"note\nQx31": 1`). A quote of another
    /// kind opens inside a quote (`'a "b" c'`); when a quote closes while one opened inside it is
    /// still open (`'x "y' z"`, `'x "y' "c` before a line break), the quotes overlap, which quote
    /// closes cannot be told, and the text is cut at the earliest quote still open. A bracket that
    /// does not close before the text ends leaves the end of its value unknown, so it cuts the text
    /// after it, also after another trigger. JSON in the text (`{"…`, `[{…`, `["…`,
    /// `[[…`) is parsed and redacted by the key rule for structured input, within the limits listed
    /// under "Limits"; JSON that does not parse, or is longer than 64 Ki scalars, cuts the text at
    /// its first bracket.
    ///
    /// **URLs.** A URL in free text is shown only when it is clean — `scheme://host` and an
    /// optional path of ASCII letters, digits, `.`, `_`, `-` and `/` (no `?`, `#`, `;`, `%`, `=`,
    /// `:`, `@` or `\`), whose host and segments name no secret, followed by white space, a line
    /// break, the end of the text or one `.`, `,`, `!` or `)` before one of those — and any other
    /// URL cuts the text where it starts, also one that a quote, a backtick, `>`, `]`, `}` or a
    /// `?`, `#`, `;` or `:` follows (`see https://x.example/a'#token` keeps `see `);
    /// ``allowedQueryParameters`` applies only to ``redact(url:)``. A clean URL is written as
    /// ``redact(url:)`` writes it, so an identifier in its path becomes `:id`
    /// (`GET https://api.example.com/users/12345678 200` keeps
    /// `GET https://api.example.com/users/:id 200`), its last segment is read with the next word
    /// (`…/to ken hunter2`), and one longer than 256 characters cuts the text like any long word.
    /// `see https://x.example/a?page=2 ok` keeps `see `, with `page` allowed or not.
    public func redact(text: String) -> String {
        guard isEnabled else { return text }
        let length = text.unicodeScalars.count
        // A text longer than the policy reads is hidden before a copy of its scalars is made.
        guard readsText(ofLength: length) else { return Self.replacement }
        return redact(text, nesting: .text(length: length), compatibility: readings(length: length))
    }

    /// Whether a text of `length` scalars is read at all. A longer one is hidden whole, as
    /// ``TextFindings/wholeText``, and never reaches a ``Span``.
    func readsText(ofLength length: Int) -> Bool {
        length <= textLengthLimit
    }

    /// The findings in free text. `nesting` says which documents the text is in; a text inside
    /// one whose JSON or URL goes past a limit is hidden whole.
    func textSpans(in scalars: [Unicode.Scalar], compatibility: CompatibilityText, role: FreeTextScanner.Role = .text, nesting: Nesting) -> TextFindings {
        guard !scalars.isEmpty else { return .none }
        guard readsText(ofLength: scalars.count) else { return .wholeText }
        guard !Self.isQuietWord(scalars, names: compatibility.secretNames) else { return .none }
        // The free-text rule cuts the text at the first scalar outside the safe alphabet at the
        // latest, so the copy is made only as far as the scan and the detectors read.
        let text = NormalizedText(scalars, compatibility: compatibility, extent: .scanned)
        return textSpans(in: scalars, text: text, compatibility: compatibility, role: role, nesting: nesting)
    }

    /// ``textSpans(in:compatibility:role:nesting:)`` on a scanning copy that is already made.
    /// With `detectsInRegions` the value detectors also read the JSON and URLs in the text, which
    /// a path segment needs: a URL in one keeps its host, and a token in the host must still make
    /// the segment `:id`. A text inside a document found in the input that the reading budget no
    /// longer covers (see ``ReadingBudget``) is hidden whole, and so is a text longer than
    /// ``textLengthLimit``, whose offsets a ``Span`` cannot hold.
    ///
    /// The free-text rule cuts the text at its first trigger (see ``FreeTextScanner``): what comes
    /// before the cut keeps the findings of the JSON, URLs and value detectors in it, and the cut
    /// hides the rest.
    func textSpans(
        in scalars: [Unicode.Scalar], text: NormalizedText, compatibility: CompatibilityText, role: FreeTextScanner.Role = .text,
        nesting: Nesting, detectsInRegions: Bool = false
    ) -> TextFindings {
        guard !scalars.isEmpty else { return .none }
        guard readsText(ofLength: scalars.count), nesting.reads(scalars.count) else { return .wholeText }
        var scanner = FreeTextScanner(source: scalars, text: text, policy: self, compatibility: compatibility, role: role, nesting: nesting)
        scanner.run()
        if scanner.hidesWholeText { return .wholeText }
        let cut = scanner.cut.flatMap { $0 < scalars.count ? [Span(start: $0, end: scalars.count, kind: .secretFields, replacement: Self.replacement)] : nil } ?? []
        // The detectors look for findings only before the cut, which hides the rest.
        let startLimit = scanner.cut.map(text.byteIndex(atOrAfter:)) ?? text.count
        // JSON and URLs were redacted by their own rules; the detectors do not read them again.
        let regions = scanner.regions
        // The findings are collected in the array of the value detectors, which is the largest (a
        // megabyte of addresses finds a hundred thousand of them), made with room for the rest.
        var found: [Span]
        if regions.isEmpty || detectsInRegions {
            found = detectorSpans(in: text, startLimit: startLimit, extra: scanner.spans.count + cut.count)
        } else {
            let crossing = Self.crossing(detectorSpans(in: text, startLimit: startLimit), regions)
            found = detectorSpans(in: text.masking(regions), startLimit: startLimit, extra: crossing.count + scanner.spans.count + cut.count)
            found += crossing
        }
        found += scanner.spans
        found += cut
        // Handed over, not copied: an unoptimized build would otherwise keep `found` and copy it
        // when the spans are sorted.
        let spans = Self.merged(consume found)
        return spans.isEmpty ? .none : .spans(spans)
    }

    /// The longest text that is read: one whose scalar offsets fit in the 28 bits a ``Span`` keeps
    /// them in, 2^28 − 1 (256 Mi) scalars. A longer one is hidden whole, and a longer body is
    /// omitted (``bodySizeLimit`` is shorter).
    static let maximumTextLength = Span.maximumOffset

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
            return crosses ? Span(start: span.start, end: span.end, kind: span.kind, replacement: replacement) : nil
        }
    }

    /// The longest text ``isQuietWord(_:)`` takes: the shortest card number has 13 digits, an
    /// IBAN 15 characters and a long token 32.
    static let quietWordLength = 12

    /// Whether a text is one word of at most ``quietWordLength`` ASCII letters and digits with no
    /// secret word in it, such as most JSON strings, path segments and query names. No rule and
    /// no detector finds anything in such a word, so it is not scanned; reading every one of them
    /// took most of the time of a JSON array of short strings and of a URL of many segments.
    /// `names` are the secret names the word is compared with.
    static func isQuietWord(_ scalars: [Unicode.Scalar], names: SecretNameTable) -> Bool {
        guard scalars.count <= quietWordLength else { return false }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(scalars.count)
        for scalar in scalars {
            guard scalar.isASCII, ASCII.isAlphanumeric(UInt8(scalar.value)) else { return false }
            bytes.append(UInt8(scalar.value))
        }
        return PlainName(bytes: bytes, maximumLength: nil)?.namesSecret(in: names) == false
    }

    /// The findings of the value detectors that start before byte
    /// `startLimit`, where free text is cut (see ``NormalizedText``'s detectors), in an array with
    /// room for `extra` more. The detectors run twice, first to count (see ``SpanSink``).
    func detectorSpans(in text: NormalizedText, startLimit: Int = .max, extra: Int = 0) -> [Span] {
        var counter = SpanSink()
        runDetectors(on: text, startLimit: startLimit, into: &counter)
        var sink = SpanSink(capacity: counter.count + extra)
        if counter.count > 0 { runDetectors(on: text, startLimit: startLimit, into: &sink) }
        return sink.spans
    }

    private func runDetectors(on text: NormalizedText, startLimit: Int, into sink: inout SpanSink) {
        text.userInfoPasswordSpans(startLimit: startLimit, into: &sink)
        text.bearerSpans(startLimit: startLimit, into: &sink)
        text.jsonWebTokenSpans(startLimit: startLimit, into: &sink)
        text.emailSpans(startLimit: startLimit, into: &sink)
        text.cardSpans(startLimit: startLimit, into: &sink)
        text.ibanSpans(startLimit: startLimit, into: &sink)
        text.longTokenSpans(startLimit: startLimit, into: &sink)
    }

    /// The text redacted as free text, and what was found in it; nil when nothing was.
    func redactedText(
        _ scalars: [Unicode.Scalar], compatibility: CompatibilityText, role: FreeTextScanner.Role = .text, nesting: Nesting
    ) -> (text: String, kind: Kinds)? {
        switch textSpans(in: scalars, compatibility: compatibility, role: role, nesting: nesting) {
        case .none:
            return nil
        case .wholeText:
            return (Self.replacement, .secretFields)
        case .spans(let spans):
            return (Self.replacing(spans, in: scalars), spans.reduce(into: Kinds()) { $0.formUnion($1.kind) })
        }
    }

    /// A text inside a document or a list (a form value, a query value, a header value, a
    /// `text/plain` body), redacted as free text with its nesting and readings table.
    func redact(_ text: String, nesting: Nesting, compatibility: CompatibilityText) -> String {
        redactedText(Array(text.unicodeScalars), compatibility: compatibility, nesting: nesting)?.text ?? text
    }

    /// A key that is written out (a form or multipart field name, a query parameter name) read as
    /// free text in the ``FreeTextScanner/Role/name`` role.
    func redactedName(_ name: String, nesting: Nesting, compatibility: CompatibilityText) -> String {
        redactedText(Array(name.unicodeScalars), compatibility: compatibility, role: .name, nesting: nesting)?.text ?? name
    }
}
