/// Replacements: where findings are, how they join, and the text they make.
extension RedactionPolicy {
    /// A replacement, in offsets of the original scalars, and the kinds of what it hides. The two
    /// offsets and the kinds are packed into 64 bits, so a span takes 24 bytes, not 40: a megabyte
    /// of short findings (`a@b.cd `, `1:2@`) holds up to a quarter of a million of them. A text
    /// longer than ``maximumOffset`` scalars is hidden whole before any span is made (see
    /// ``TextFindings/wholeText``), so the offsets of a text that is read fit. A span made with an
    /// offset that does not fit fails closed: it hides the whole text it is applied to with
    /// ``RedactionPolicy/replacement``. Keeping the low 28 bits of such an offset, as 2.1.1 did,
    /// ended the span near the start of the text and wrote the rest of it as it was.
    struct Span {
        let replacement: String
        /// The start in the low 28 bits, the end in the next 28, the kinds in the next 7 and, in
        /// the top bit, whether the span hides the whole text.
        private let packed: UInt64

        init(start: Int, end: Int, kind: Kinds, replacement: String) {
            let kinds = UInt64(kind.rawValue & Self.kindMask) << 56
            guard Self.fits(start), Self.fits(end) else {
                self.replacement = RedactionPolicy.replacement
                packed = Self.wholeTextFlag | kinds
                return
            }
            self.replacement = replacement
            packed = UInt64(start) | UInt64(end) << 28 | kinds
        }

        /// The largest offset a span holds: 2^28 − 1.
        static let maximumOffset = Int(offsetMask)

        private static let offsetMask: UInt64 = (1 << 28) - 1
        private static let kindMask = 0x7F
        private static let wholeTextFlag: UInt64 = 1 << 63

        private static func fits(_ offset: Int) -> Bool {
            offset >= 0 && offset <= maximumOffset
        }

        /// Whether the span hides the whole text, however long it is: an offset it was made with
        /// did not fit.
        var hidesWholeText: Bool { packed & Self.wholeTextFlag != 0 }

        /// The offset of the first scalar replaced; 0 for a span that hides the whole text. A
        /// new offset that does not fit makes the span hide the whole text, as in ``init``.
        var start: Int {
            get { hidesWholeText ? 0 : Int(packed & Self.offsetMask) }
            set { self = Span(start: newValue, end: end, kind: kind, replacement: replacement) }
        }

        /// The offset after the last scalar replaced. A span that hides the whole text ends at
        /// `Int.max`, which ``replacing(_:in:)`` reads as the end of the text.
        var end: Int {
            get { hidesWholeText ? .max : Int(packed >> 28 & Self.offsetMask) }
            set { self = Span(start: start, end: newValue, kind: kind, replacement: replacement) }
        }

        var kind: Kinds { Kinds(rawValue: Int(packed >> 56) & Self.kindMask) }
    }

    /// What the free-text rule finds in a text.
    enum TextFindings {
        /// Nothing: the text is written as it is.
        case none
        /// The text is hidden whole and written as ``RedactionPolicy/replacement``, without a
        /// ``Span``: it is longer than the policy reads (see ``maximumTextLength``), a document it
        /// is in has no reading budget left for it, or the scanner cannot read it.
        case wholeText
        /// The findings, in order and without overlaps; never empty.
        case spans([Span])

        /// Whether nothing was found.
        var isEmpty: Bool {
            if case .none = self { return true }
            return false
        }
    }

    /// The scalars with every span replaced; `spans` are in order and do not overlap. The UTF-8 of
    /// the output is counted first and written once into the string, so the output is never held
    /// twice. A span ends at the end of the text at the latest, so one that hides the whole text
    /// replaces all of it.
    static func replacing(_ spans: [Span], in scalars: [Unicode.Scalar]) -> String {
        // Appending to a String.UnicodeScalarView piece by piece copies what is already there,
        // which made many matches take quadratic time.
        func utf8Count(_ range: Range<Int>) -> Int {
            var count = 0
            for index in range { count += UTF8.width(scalars[index]) }
            return count
        }
        func bounds(_ span: Span) -> Range<Int> {
            min(span.start, scalars.count)..<min(span.end, scalars.count)
        }
        var length = 0
        var position = 0
        for span in spans {
            let range = bounds(span)
            length += utf8Count(position..<range.lowerBound) + span.replacement.utf8.count
            position = range.upperBound
        }
        length += utf8Count(position..<scalars.count)
        return String(unsafeUninitializedCapacity: length) { output in
            var written = 0
            func append(_ range: Range<Int>) {
                for index in range {
                    let scalar = scalars[index]
                    if scalar.isASCII {
                        output[written] = UInt8(scalar.value)
                        written += 1
                    } else {
                        UTF8.encode(scalar) { byte in
                            output[written] = byte
                            written += 1
                        }
                    }
                }
            }
            var position = 0
            for span in spans {
                let range = bounds(span)
                append(position..<range.lowerBound)
                for byte in span.replacement.utf8 {
                    output[written] = byte
                    written += 1
                }
                position = range.upperBound
            }
            append(position..<scalars.count)
            return written
        }
    }

    /// The spans in order and without overlaps. A span inside a mask (an address, a card number)
    /// turns the mask into ``replacement``, since the mask shows part of what it covers; spans that
    /// partly overlap are joined into one ``replacement``. A ``replacement`` that covers the same
    /// characters as another finding, or lies inside one, always wins: the cut of free text that
    /// starts and ends where a clean URL does (`(https://api.example.com/users/12345678`) hides the
    /// URL, which otherwise kept its `:id` form.
    ///
    /// The spans are sorted and joined in the array passed in, which a text of many findings (a
    /// megabyte of addresses) otherwise copied twice, and sorted without a buffer (see
    /// ``sortRuns(_:)``).
    static func merged(_ spans: consuming [Span]) -> [Span] {
        var spans = spans
        sortRuns(&spans)
        var count = 0
        for index in spans.indices {
            let span = spans[index]
            guard count > 0, span.start < spans[count - 1].end else {
                spans[count] = span
                count += 1
                continue
            }
            let last = spans[count - 1]
            guard span.end > last.end else {
                let hides = span.replacement == replacement || (!span.kind.isEmpty && span.kind != last.kind)
                if last.replacement != replacement, hides {
                    spans[count - 1] = Span(start: last.start, end: last.end, kind: last.kind.union(span.kind), replacement: replacement)
                }
                continue
            }
            spans[count - 1] = Span(start: last.start, end: span.end, kind: last.kind.union(span.kind), replacement: replacement)
        }
        spans.removeLast(spans.count - count)
        return spans
    }
}

extension Array {
    /// Appends `element`, growing the capacity by a quarter when it is full instead of doubling it:
    /// the findings of the JSON in a megabyte of text would otherwise leave up to as much capacity
    /// unused as they take.
    mutating func appendGrowingByAQuarter(_ element: Element) {
        if count == capacity { reserveCapacity(count + count / 4 + 16) }
        append(element)
    }
}
