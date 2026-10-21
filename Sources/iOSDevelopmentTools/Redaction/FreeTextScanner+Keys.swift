/// The key before a separator in free text, read back from the separator.
extension FreeTextScanner {
    /// The key before the separator at `separator`, as written, invisible characters before it
    /// included: after white space and line breaks, everything back to white space, a line break,
    /// another separator, `,`, `?` or `|`, or `&` or `;` between two pairs (`a=1&b=`,
    /// `text/plain;q=`). An `&` that no pair ends before and a `;` after an `&` belong to the key,
    /// as in a character reference (`&#98;`) or a broken one (`k_&_#101;y`). The key is read
    /// without the brackets and quotes it starts with and the quotes it ends with, each also
    /// escaped with a backslash. So `user[name]`, `a$b`, `\u{70}ass` and `MyApp[42]` are keys
    /// that are not plain ASCII, while `(user`, `"user"` and `\"user\"` read as `user`. Nil when
    /// there is none. The search stops at the separator before, so every byte is read back once
    /// at most.
    func keyName(before separator: Int) -> [Unicode.Scalar]? {
        var end = separator
        while end > 0, text.isSpace(end - 1) || text.isLineTerminator(end - 1) { end -= 1 }
        var start = end
        // Once no pair ends before an `&`, none ends before the ones further back either, so
        // each byte is read back once at most.
        var pairsEnd = true
        while start > 0 {
            if let reference = referenceStart(endingAt: start) {
                start = reference
                continue
            }
            let byte = text.bytes[start - 1]
            if byte == UInt8(ascii: "&") {
                pairsEnd = pairsEnd && endsPair(before: start - 1)
                if pairsEnd { break }
            } else if byte == UInt8(ascii: ";") {
                guard followsAmpersand(start - 1) else { break }
            } else if endsKey(start - 1) {
                break
            }
            start -= 1
        }
        guard start < end else { return nil }
        var name = source[text.originalWithInvisiblesBefore(start..<end)]
        while let first = name.first {
            if Self.keyOpenings.contains(first) {
                name = name.dropFirst()
            } else if first == "\\", let next = name.dropFirst().first, Self.keyQuotes.contains(next) {
                name = name.dropFirst(2)
            } else {
                break
            }
        }
        while let last = name.last, Self.keyQuotes.contains(last) {
            name = name.dropLast()
            if name.last == "\\" { name = name.dropLast() }
        }
        return Array(name)
    }

    /// Whether a pair ends before the `&` at `i`: a separator comes before it, after other text
    /// and before white space. Otherwise the `&` is part of the key (`k_&_#101;y`), not between
    /// two pairs (`a=1&b=2`).
    private func endsPair(before i: Int) -> Bool {
        var k = i
        while k > 0 {
            k -= 1
            if text.isSpace(k) || text.isLineTerminator(k) || Self.keyWordBoundaries.contains(text.bytes[k]) { return false }
            if isSeparator(k) { return true }
        }
        return false
    }

    /// Whether an `&` comes before the `;` at `i`, after other text at most and within the length
    /// of a character reference, as in a broken one (`&_#x70;`).
    private func followsAmpersand(_ i: Int) -> Bool {
        var k = i
        while k > 0, i - k < Self.longestReference {
            k -= 1
            if text.bytes[k] == UInt8(ascii: "&") { return true }
            if endsKey(k) { return false }
        }
        return false
    }

    private func endsKey(_ i: Int) -> Bool {
        text.isSpace(i) || text.isLineTerminator(i) || isSeparator(i) || Self.keyBoundaries.contains(text.bytes[i])
    }

    private static let keyBoundaries = ByteSet(",;&?|")
    private static let keyOpenings: Set<Unicode.Scalar> = ["(", "[", "{", "<", "'", "\"", "`"]
    private static let keyQuotes: Set<Unicode.Scalar> = ["'", "\"", "`"]

    /// Whether the last words before the separator at `separator`, on its line and after the
    /// separator, `,` or `?` before them, read as one name with their escapes decoded, name a
    /// secret that ends in the word next to the separator: a key split by white space or
    /// punctuation (`pass word=`, `c v v:`, `id_to ke n:`, `c%2556|v:`, `secret&#107.;ey=`). A
    /// single word of letters and digits was read already. At most ``keyWords`` words and
    /// ``keyBytes`` bytes are read back.
    func keyWordsNameSecret(before separator: Int) -> Bool {
        var end = separator
        while end > 0, text.isSpace(end - 1) || text.isLineTerminator(end - 1) { end -= 1 }
        var start = end
        var words = 1
        while start > 0, end - start < Self.keyBytes {
            let byte = text.bytes[start - 1]
            if text.isLineTerminator(start - 1) || isSeparator(start - 1) || Self.keyWordBoundaries.contains(byte) { break }
            if text.isSpace(start - 1), !text.isSpace(start) {
                guard words < Self.keyWords else { break }
                words += 1
            }
            start -= 1
        }
        let region = start..<end
        guard region.contains(where: { !text.isAlphanumeric($0) }) else { return false }
        let original = text.originalWithInvisiblesBefore(region)
        if source[original].contains(where: EscapeDecoder.startsEscape) {
            return Self.wordsNameSecret(Array(source[original]), endingInLastWord: true, policy: policy, compatibility: compatibility)
        }
        var ranges: [Range<Int>] = []
        var k = start
        while k < end {
            guard !text.isSpace(k) else {
                k += 1
                continue
            }
            let wordStart = k
            while k < end, !text.isSpace(k) { k += 1 }
            ranges.append(wordStart..<k)
        }
        guard let last = ranges.last, let reading = LooseReading(text, ranges, source: source, names: policy.secretNameTable) else { return false }
        return reading.secretEnd { $0.upperBound > last.lowerBound } != nil
    }

    private static let keyWordBoundaries = ByteSet(",?")
    /// The words and bytes before a separator that ``keyWordsNameSecret(before:)`` reads.
    private static let keyWords = 16
    private static let keyBytes = 128

    /// The `&` of a character reference that ends right before byte `i` (`&#98;`, `&amp;`), or of
    /// one that starts at byte `i - 1` without its `;` (`&#98`).
    private func referenceStart(endingAt i: Int) -> Int? {
        let last = text.bytes[i - 1]
        if last == UInt8(ascii: "&") { return referenceLength(at: i - 1) != nil ? i - 1 : nil }
        guard last == UInt8(ascii: ";") else { return nil }
        var amp = i - 2
        while amp >= 0, i - amp <= Self.longestReference {
            if text.bytes[amp] == UInt8(ascii: "&") { return referenceLength(at: amp) == i - amp ? amp : nil }
            amp -= 1
        }
        return nil
    }

    /// `&amp;#x10FFFF;` and a few more digits.
    private static let longestReference = 16
}
