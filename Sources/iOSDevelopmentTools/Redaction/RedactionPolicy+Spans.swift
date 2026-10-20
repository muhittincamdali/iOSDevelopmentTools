/// Replacements: where findings are, how they join, and the text they make.
extension RedactionPolicy {
    /// A replacement, in offsets of the original scalars. The offsets are stored in 32 bits (see
    /// ``maximumTextLength``): a megabyte of findings holds over a hundred thousand spans.
    struct Span {
        private var storedStart: UInt32
        private var storedEnd: UInt32
        var replacement: String

        init(start: Int, end: Int, replacement: String) {
            storedStart = UInt32(truncatingIfNeeded: start)
            storedEnd = UInt32(truncatingIfNeeded: end)
            self.replacement = replacement
        }

        var start: Int { Int(storedStart) }
        var end: Int { Int(storedEnd) }
    }

    /// The scalars with every span replaced; `spans` are in order and do not overlap.
    static func replacing(_ spans: [Span], in scalars: [Unicode.Scalar]) -> String {
        // Appending to a String.UnicodeScalarView piece by piece copies what is already there,
        // which made many matches take quadratic time. The UTF-8 is counted first and written
        // into the string once, with no copy of it in between.
        func utf8Count(_ piece: ArraySlice<Unicode.Scalar>) -> Int { piece.reduce(0) { $0 + UTF8.width($1) } }
        var count = 0
        var position = 0
        for span in spans {
            count += utf8Count(scalars[position..<span.start]) + span.replacement.utf8.count
            position = span.end
        }
        count += utf8Count(scalars[position...])
        return String(unsafeUninitializedCapacity: count) { buffer in
            var written = 0
            func write(_ piece: some Sequence<Unicode.Scalar>) {
                for scalar in piece {
                    UTF8.encode(scalar) { buffer[written] = $0; written += 1 }
                }
            }
            var position = 0
            for span in spans {
                write(scalars[position..<span.start])
                for byte in span.replacement.utf8 { buffer[written] = byte; written += 1 }
                position = span.end
            }
            write(scalars[position...])
            return written
        }
    }

    /// The spans in order and without overlaps. A finding inside a span that writes something
    /// else than ``replacement`` (a redacted URL, a JSON string written again) turns that span into
    /// ``replacement``, since what it writes may show part of the finding; spans that partly
    /// overlap are joined into one ``replacement``.
    ///
    /// The spans are sorted and joined in place, so a text of many findings holds one list of them.
    static func merged(_ spans: consuming [Span]) -> [Span] {
        spans.sort { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }
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
                if last.replacement != replacement, span.replacement != last.replacement {
                    spans[count - 1] = Span(start: last.start, end: last.end, replacement: replacement)
                }
                continue
            }
            spans[count - 1] = Span(start: last.start, end: span.end, replacement: replacement)
        }
        spans.removeLast(spans.count - count)
        return spans
    }
}
