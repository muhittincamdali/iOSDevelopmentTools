import Foundation

/// Finding keys in free text. The line is read as Unicode scalars: a key is a run of scalars
/// between white space or `& ; , ? { ( < |` and the `=` or `:` after it. The key is also read
/// more widely, with `&` and `;` inside it (see ``KeyToken``), and the value is hidden when
/// either reading hides it.
extension RedactionPolicy {
    /// Characters that end a key and start the next one, besides white space and `=` or `:`.
    private static let keyBoundaries: Set<Unicode.Scalar> = ["&", ";", ",", "?", "{", "(", "<", "|"]

    /// The last runs of a line are kept, so a secret name split by spaces or separators
    /// (`pass word=`, `pass;word=`, `api:key=`) is still found when they are joined. This many.
    private static let joinedRunLimit = 3

    /// How far back the opening quote of a quoted key is looked for.
    private static let quotedKeyLimit = 256

    /// A run of scalars between boundaries: its range in the line and where it starts in the output.
    private struct Run {
        let start: Int
        var end: Int
        let outputStart: Int
    }

    /// Where the widest key that an `=` or `:` could close starts. After a value, `&` and `;` end
    /// it, as in `a=1&b=2`. Before one, an `&` is part of it, and so is a `;` after that `&`, so a
    /// broken escape such as `pass&#1\u{301}19;ord=` is read as one key, which is not plain,
    /// rather than as `ord`.
    private struct KeyToken {
        var start = 0
        /// Whether the scan is after an `=` or `:`, before the value ended.
        private var isInValue = false
        private var hasValueStarted = false
        private var holdsAmpersand = false

        /// After an `=` or `:` at `index - 1`.
        mutating func startValue(at index: Int) {
            restart(at: index)
            isInValue = true
        }

        /// After a quoted value that was hidden, which ends before `index`.
        mutating func endHiddenValue(at index: Int) {
            startValue(at: index)
            hasValueStarted = true
        }

        private mutating func restart(at index: Int) {
            start = index
            isInValue = false
            hasValueStarted = false
            holdsAmpersand = false
        }

        mutating func read(_ scalar: Unicode.Scalar, at index: Int, isCharacterReference: Bool) {
            if scalar.properties.isWhitespace {
                let keepsValue = isInValue && !hasValueStarted
                restart(at: index + 1)
                isInValue = keepsValue
            } else if !isCharacterReference, scalar == "&" || scalar == ";" {
                if isInValue {
                    restart(at: index + 1)
                } else if scalar == "&" {
                    holdsAmpersand = true
                } else if !holdsAmpersand {
                    restart(at: index + 1)
                }
            } else if !isCharacterReference, RedactionPolicy.keyBoundaries.contains(scalar) {
                restart(at: index + 1)
            } else if isInValue {
                hasValueStarted = true
            }
        }
    }

    /// The runs read so far on a line.
    private struct Runs {
        /// The run being read.
        var current: Run?
        /// The last finished run, while only spaces or tabs follow it: it may still be a key, as
        /// in `key = value`.
        var key: Run?
        /// The last finished runs, oldest first.
        var window: [Run] = []

        mutating func finishCurrent(at end: Int) {
            guard var run = current else { return }
            run.end = end
            window.append(run)
            if window.count > RedactionPolicy.joinedRunLimit { window.removeFirst() }
            key = run
            current = nil
        }
    }

    /// One line with the values of hidden keys replaced, and the rest of the line replaced after
    /// a secret word whose value cannot be delimited; `valueContinues` when a hidden key ends the
    /// line, so its value may be on the next one.
    func redactKeyedValues(in line: [Unicode.Scalar]) -> (scalars: [Unicode.Scalar], valueContinues: Bool) {
        var output: [Unicode.Scalar] = []
        output.reserveCapacity(line.count)
        var runs = Runs()
        var token = KeyToken()
        var index = 0
        while index < line.count {
            let scalar = line[index]
            let entityLength = scalar == "&" ? Self.characterReferenceLength(in: line, at: index) : 0
            if scalar == "=" || scalar == ":" {
                runs.finishCurrent(at: index)
                let hidesRun = runs.key.map { hidesValue(ofKey: $0, window: runs.window, in: line) } ?? false
                let hides = hidesRun || hidesValue(ofTextKey: line[token.start..<index])
                runs.key = nil
                token.startValue(at: index + 1)
                output.append(scalar)
                guard hides else {
                    index += 1
                    continue
                }
                switch appendHiddenValue(of: line, from: index + 1, to: &output) {
                case .resume(let next):
                    index = next
                    token.endHiddenValue(at: next)
                case .restOfLine: return (output, false)
                case .onNextLine: return (output, true)
                }
                continue
            }
            token.read(scalar, at: index, isCharacterReference: entityLength > 0)
            if Self.isSpaceOrTab(scalar) {
                runs.finishCurrent(at: index)
            } else if entityLength == 0, Self.keyBoundaries.contains(scalar) || scalar.properties.isWhitespace {
                runs.finishCurrent(at: index)
                if let key = runs.key, hidesRest(after: key, in: line, output: &output) { return (output, false) }
                runs.key = nil
            } else if runs.current == nil {
                if let key = runs.key, hidesRest(after: key, in: line, output: &output) { return (output, false) }
                runs.key = nil
                runs.current = Run(start: index, end: index, outputStart: output.count)
            }
            let length = max(entityLength, 1)
            output += line[index..<(index + length)]
            index += length
        }
        runs.finishCurrent(at: line.count)
        if let key = runs.key { _ = hidesRest(after: key, in: line, output: &output) }
        return (output, false)
    }

    /// The length of an HTML character reference (`&#119;`, `&#x77;`) at `index`, which is part of
    /// a key rather than a boundary; 0 when there is none.
    private static func characterReferenceLength(in line: [Unicode.Scalar], at index: Int) -> Int {
        guard index + 3 < line.count, line[index + 1] == "#" else { return 0 }
        let isHex = line[index + 2] == "x" || line[index + 2] == "X"
        var end = index + (isHex ? 3 : 2)
        let digitsStart = end
        while end < line.count, end - digitsStart < 8,
              isHex ? line[end].properties.isASCIIHexDigit : ValueDetectors.isDigit(line[end]) {
            end += 1
        }
        guard end > digitsStart, end < line.count, line[end] == ";" else { return 0 }
        return end + 1 - index
    }

    /// Whether the value after this key is hidden: the key (or the quoted key it closes) is a
    /// secret name or not plain, or it joined with the one or two runs before it is a secret name.
    private func hidesValue(ofKey key: Run, window: [Run], in line: [Unicode.Scalar]) -> Bool {
        let keyRange = Self.quotedKey(endingAt: key, in: line) ?? key.start..<key.end
        if hidesValue(ofTextKey: line[keyRange]) { return true }
        guard window.count > 1, window.last?.start == key.start else { return false }
        for count in 2...window.count {
            let joined = window.suffix(count).map { String(String.UnicodeScalarView(line[$0.start..<$0.end])) }.joined()
            if isSecret(FoldedKey(joined)) { return true }
        }
        return false
    }

    /// The range from the opening quote to the closing one when the run ends with a quote, as in
    /// `"pass word":`; `nil` otherwise or when the opening quote is not found nearby.
    private static func quotedKey(endingAt run: Run, in line: [Unicode.Scalar]) -> Range<Int>? {
        let close = run.end - 1
        guard close >= run.start, line[close] == "\"" || line[close] == "'" else { return nil }
        let lowest = max(0, close - quotedKeyLimit)
        guard close > lowest, let open = line[lowest..<close].lastIndex(of: line[close]) else { return nil }
        return open..<run.end
    }

    /// Whether the value of a key found in text is hidden. Quotes around the key, also escaped as
    /// in `\"password\"`, are not part of it; other backslashes are, so `\u0070assword` is decoded.
    private func hidesValue(ofTextKey key: ArraySlice<Unicode.Scalar>) -> Bool {
        let quotes: Set<Unicode.Scalar> = ["\"", "'"]
        var trimmed = key
        while true {
            if let first = trimmed.first, quotes.contains(first) {
                trimmed = trimmed.dropFirst()
            } else if trimmed.first == "\\", let second = trimmed.dropFirst().first, quotes.contains(second) {
                trimmed = trimmed.dropFirst(2)
            } else {
                break
            }
        }
        while let last = trimmed.last, quotes.contains(last) {
            trimmed = trimmed.dropLast()
            if trimmed.last == "\\" { trimmed = trimmed.dropLast() }
        }
        return hidesValue(of: FoldedKey(String(String.UnicodeScalarView(trimmed))))
    }

    /// Replaces the rest of the line after a secret word in a run that no `=` or `:` follows,
    /// and returns `true`; returns `false` when the run holds no secret word or no letter or digit
    /// follows the word on the line.
    ///
    /// For a run with characters outside ASCII, the words are read after NFKC (so `ｔｏｋｅｎ` is
    /// `token`), and the run itself is replaced too, because its words cannot be mapped back. The
    /// same holds for a secret word in mixed case, such as `tOkEn`, which is found only once the
    /// run is lowercased.
    private func hidesRest(after run: Run, in line: [Unicode.Scalar], output: inout [Unicode.Scalar]) -> Bool {
        let scalars = line[run.start..<run.end]
        let isASCII = scalars.allSatisfy(\.isASCII)
        let text = String(String.UnicodeScalarView(scalars))
        let normalized = isASCII ? text : text.precomposedStringWithCompatibilityMapping
        let words = FoldedKey.words(in: normalized)
        var cut = run.start
        if let secretIndex = words.firstIndex(where: secretNameMatcher.isName) {
            if isASCII, let wordEnd = Self.endOfWord(at: secretIndex, in: scalars) {
                guard line[wordEnd...].contains(where: Self.isLetterOrNumber) else { return false }
                cut = wordEnd
            } else {
                let isLastWord = secretIndex == words.count - 1
                guard !isLastWord || line[run.end...].contains(where: Self.isLetterOrNumber) else { return false }
            }
        } else {
            let lowercasedWords = FoldedKey.words(in: normalized.lowercased())
            guard let secretIndex = lowercasedWords.firstIndex(where: secretNameMatcher.isName) else { return false }
            let isLastWord = secretIndex == lowercasedWords.count - 1
            guard !isLastWord || line[run.end...].contains(where: Self.isLetterOrNumber) else { return false }
        }
        output.removeSubrange((run.outputStart + cut - run.start)...)
        if cut > run.start, cut < line.count, Self.isSpaceOrTab(line[cut]) { output.append(" ") }
        output += Self.replacement.unicodeScalars
        return true
    }

    /// The index after the `wordIndex`-th word of an ASCII run, counting words as
    /// ``FoldedKey/words(in:)`` does.
    private static func endOfWord(at wordIndex: Int, in scalars: ArraySlice<Unicode.Scalar>) -> Int? {
        var count = -1
        var previous: Unicode.Scalar?
        for index in scalars.indices {
            let scalar = scalars[index]
            guard FoldedKey.isASCIILetterOrDigit(scalar) else {
                if previous != nil, count == wordIndex { return index }
                previous = nil
                continue
            }
            let startsWord = previous.map { ("A"..."Z").contains(scalar) && FoldedKey.isLowercaseLetterOrDigit($0) } ?? true
            if startsWord {
                if count == wordIndex { return index }
                count += 1
            }
            previous = scalar
        }
        return count == wordIndex ? scalars.endIndex : nil
    }
}
