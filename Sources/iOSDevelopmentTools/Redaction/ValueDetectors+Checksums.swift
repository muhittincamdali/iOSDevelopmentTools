import Foundation

extension ValueDetectors {
    /// Detectors that confirm a match with a checksum, so ordinary numbers are rarely hidden.
    enum Checksums {
        static let cardDigits = 13...19
        static let ibanLength = 15...34

        /// Card numbers written in groups have at most this many digits per group (4-4-4-4, 4-6-5).
        static let maximumCardGroupLength = 6

        /// 13 to 19 digits, optionally grouped by single spaces or hyphens, that pass the Luhn check.
        static func cardNumbers(in scalars: [Unicode.Scalar]) -> [Range<Int>] {
            var ranges: [Range<Int>] = []
            var index = 0
            while index < scalars.count {
                guard isDigit(scalars[index]), index == 0 || !isDigit(scalars[index - 1]) else {
                    index += 1
                    continue
                }
                let start = index
                var digits: [Int] = []
                var groupLengths = [0]
                var end = index
                while index < scalars.count {
                    if isDigit(scalars[index]) {
                        digits.append(Int(scalars[index].value - 0x30))
                        groupLengths[groupLengths.count - 1] += 1
                        index += 1
                        end = index
                    } else if scalars[index] == " " || scalars[index] == "-", index + 1 < scalars.count, isDigit(scalars[index + 1]) {
                        groupLengths.append(0)
                        index += 1
                    } else {
                        break
                    }
                }
                if cardDigits.contains(digits.count), passesLuhn(digits), isCardLayout(groupLengths, start..<end, in: scalars) {
                    ranges.append(start..<end)
                }
            }
            return ranges
        }

        /// Whether grouped digits are laid out as a card number: groups of at most six digits that
        /// stand as their own word. The digits of a UUID such as `ab123456-1234-4234-8234-123456abcdef`
        /// are not, so an identifier in a log line is kept.
        private static func isCardLayout(_ groupLengths: [Int], _ range: Range<Int>, in scalars: [Unicode.Scalar]) -> Bool {
            guard groupLengths.count > 1 else { return true }
            guard groupLengths.allSatisfy({ $0 <= maximumCardGroupLength }) else { return false }
            let touchesWordBefore = range.lowerBound > 0 && isLetterOrDigit(scalars[range.lowerBound - 1])
            let touchesWordAfter = range.upperBound < scalars.count && isLetterOrDigit(scalars[range.upperBound])
            return !touchesWordBefore && !touchesWordAfter
        }

        /// Whether a number passes the Luhn check that card numbers carry in their last digit.
        static func passesLuhn(_ digits: [Int]) -> Bool {
            var sum = 0
            for (position, digit) in digits.reversed().enumerated() {
                let doubled = position % 2 == 1 ? digit * 2 : digit
                sum += doubled > 9 ? doubled - 9 : doubled
            }
            return sum % 10 == 0
        }

        /// A country code, two check digits and up to 30 letters or digits, written as one word or in
        /// groups of four separated by single spaces, whose mod-97 remainder is 1.
        static func ibans(in scalars: [Unicode.Scalar]) -> [Range<Int>] {
            var ranges: [Range<Int>] = []
            var index = 0
            while index + 4 <= scalars.count {
                guard startsIBAN(scalars, at: index), let end = ibanEnd(scalars, from: index) else {
                    index += 1
                    continue
                }
                ranges.append(index..<end)
                index = end
            }
            return ranges
        }

        private static func startsIBAN(_ scalars: [Unicode.Scalar], at index: Int) -> Bool {
            (index == 0 || !isLetterOrDigit(scalars[index - 1]))
                && isLetter(scalars[index]) && isLetter(scalars[index + 1])
                && isDigit(scalars[index + 2]) && isDigit(scalars[index + 3])
        }

        /// IBANs printed in groups have this many characters per group, the last one fewer.
        static let ibanGroupLength = 4

        /// The end of the IBAN that starts at `start`: its whole first word, or, when that word is
        /// a group of four, the longest run of following groups that is a valid IBAN. It always
        /// ends where a word ends, so the start of a longer word is never taken for one.
        private static func ibanEnd(_ scalars: [Unicode.Scalar], from start: Int) -> Int? {
            var index = start
            while index < scalars.count, isLetterOrDigit(scalars[index]) { index += 1 }
            var characters = Array(scalars[start..<index])
            var ends = [(index, characters.count)]
            if characters.count == ibanGroupLength {
                while index + 1 < scalars.count, scalars[index] == " ", characters.count < ibanLength.upperBound {
                    var groupEnd = index + 1
                    while groupEnd < scalars.count, isLetterOrDigit(scalars[groupEnd]) { groupEnd += 1 }
                    let groupLength = groupEnd - index - 1
                    guard (1...ibanGroupLength).contains(groupLength) else { break }
                    characters += scalars[(index + 1)..<groupEnd]
                    index = groupEnd
                    ends.append((index, characters.count))
                    if groupLength < ibanGroupLength { break }
                }
            }
            for (end, count) in ends.reversed() where ibanLength.contains(count) && mod97(characters[..<count]) == 1 {
                return end
            }
            return nil
        }

        /// The IBAN remainder: the first four characters moved to the end, letters as 10 to 35.
        private static func mod97(_ characters: ArraySlice<Unicode.Scalar>) -> Int {
            let rearranged = characters.dropFirst(4) + characters.prefix(4)
            var remainder = 0
            for character in rearranged {
                let value: Int
                if isDigit(character) {
                    value = Int(character.value - 0x30)
                    remainder = (remainder * 10 + value) % 97
                } else {
                    let upper = ("a"..."z").contains(character) ? character.value - 0x20 : character.value
                    value = Int(upper - 0x41) + 10
                    remainder = (remainder * 100 + value) % 97
                }
            }
            return remainder
        }
    }
}
