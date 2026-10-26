import Testing
@testable import iOSDevelopmentTools

/// The findings are sorted in place, without the buffer of half their size that the standard sort
/// takes, by merging the runs in which they come (see ``Redactor/sortRuns(_:)``), and
/// joined so that a `[REDACTED]` span hides every finding it covers or lies inside
/// (see ``Redactor/merged(_:)``).
@Suite("Redaction corpus: order of findings")
struct RedactionSpanOrderTests {
    typealias Span = RedactionPolicy.Span

    /// Spans as a few runs in order, as the detectors give them: random starts and lengths, some
    /// equal, with a replacement that tells each apart.
    static func runs(using random: inout SeededRandom) -> [Span] {
        var spans: [Span] = []
        for _ in 0..<Int.random(in: 1...6, using: &random) {
            var start = Int.random(in: 0...20, using: &random)
            for _ in 0..<Int.random(in: 0...40, using: &random) {
                start += Int.random(in: 0...3, using: &random)
                let end = start + Int.random(in: 1...5, using: &random)
                spans.append(Span(start: start, end: end, kind: .emailAddresses, replacement: "\(spans.count)"))
            }
        }
        return spans
    }

    @Test("merging the runs sorts the spans as a stable sort does", arguments: 0..<4)
    func sortsStably(seed: Int) {
        var random = SeededRandom(seed: 0x19_5000 + UInt64(seed))
        for _ in 0..<300 {
            let spans = Self.runs(using: &random)
            let expected = spans.enumerated().sorted { first, second in
                if RedactionPolicy.isBefore(first.element, second.element) { return true }
                if RedactionPolicy.isBefore(second.element, first.element) { return false }
                return first.offset < second.offset
            }.map(\.element.replacement)
            var sorted = spans
            RedactionPolicy.sortRuns(&sorted)
            #expect(sorted.map(\.replacement) == expected)
        }
    }

    @Test("a [REDACTED] span over the same characters as another finding, or inside it, wins")
    func redactedSpanWins() {
        let redacted = RedactionPolicy.replacement
        let url = Span(start: 1, end: 39, kind: .secretFields, replacement: "https://api.example.com/users/:id")
        let cut = Span(start: 1, end: 39, kind: .secretFields, replacement: redacted)
        let inside = Span(start: 30, end: 39, kind: .secretFields, replacement: redacted)
        for spans in [[url, cut], [cut, url], [url, inside]] {
            let merged = RedactionPolicy.merged(spans)
            #expect(merged.map(\.replacement) == [redacted])
            #expect(merged.map(\.start) == [1] && merged.map(\.end) == [39])
        }
        // A finding of the same kind inside a span with another replacement, other than
        // ``RedactionPolicy/replacement``, keeps that replacement.
        let mask = Span(start: 0, end: 19, kind: .cardNumbers, replacement: "[REDACTED] [REDACTED] [REDACTED]")
        let card = Span(start: 5, end: 19, kind: .cardNumbers, replacement: "[REDACTED] [REDACTED]")
        #expect(RedactionPolicy.merged([mask, card]).map(\.replacement) == [mask.replacement])
    }

    /// The nineteenth review: an unclosed bracket before a clean URL cuts the text where the URL
    /// starts, and the cut ends where the URL does. The URL's `:id` form showed until the cut won.
    @Test("free text cut where a clean URL starts hides the URL", arguments: [
        ("(https://api.example.com/users/12345678", "([REDACTED]"),
        ("see (https://api.example.com/users/12345678", "see ([REDACTED]"),
        ("see [https://api.example.com/users/12345678", "see [[REDACTED]"),
        ("see {https://api.example.com/users/12345678", "see {[REDACTED]"),
        ("see (https://api.example.com/users/12345678/orders/987654321", "see ([REDACTED]"),
        ("see (https://api.example.com/v1/users/550e8400-e29b-41d4-a716-446655440000", "see ([REDACTED]"),
        ("x [https://api.example.com/users/12345678]", "x [[REDACTED]"),
        ("(https://x.example/a", "([REDACTED]"),
        // A clean URL that no cut covers keeps its form.
        ("GET https://api.example.com/users/12345678 200", "GET https://api.example.com/users/:id 200"),
        ("see (https://api.example.com/users/12345678) ok", "see (https://api.example.com/users/:id) ok"),
    ])
    func cutCoveringURL(input: String, expected: String) {
        #expect(Redactor().redact(input) == expected)
    }

    @Test("a span keeps its offsets and kinds in its 24 bytes")
    func packing() {
        let span = Span(start: RedactionPolicy.maximumTextLength, end: 7, kind: .all, replacement: "x")
        #expect(span.start == RedactionPolicy.maximumTextLength)
        #expect(span.end == 7)
        #expect(span.kind == .all)
        #expect(MemoryLayout<Span>.stride == 24)
        var moved = span
        moved.start = 3
        moved.end = RedactionPolicy.maximumTextLength
        #expect(moved.start == 3 && moved.end == RedactionPolicy.maximumTextLength && moved.kind == .all)
    }
}
