import Foundation

extension ValueDetectors {
    /// Detectors that confirm a match with a checksum, so ordinary numbers are rarely hidden.
    enum Checksums {
        static let cardDigits = 13...19
        static let ibanLength = 15...34

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
                var end = index
                while index < scalars.count {
                    if isDigit(scalars[index]) {
                        digits.append(Int(scalars[index].value - 0x30))
                        index += 1
                        end = index
                    } else if scalars[index] == " " || scalars[index] == "-", index + 1 < scalars.count, isDigit(scalars[index + 1]) {
                        index += 1
                    } else {
                        break
                    }
                }
                if cardDigits.contains(digits.count), passesLuhn(digits) { ranges.append(start..<end) }
            }
            return ranges
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

        /// A country code, two check digits and up to 30 letters or digits, optionally grouped by
        /// single spaces, whose mod-97 remainder is 1.
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

        /// The end of the longest valid IBAN that starts at `start`.
        private static func ibanEnd(_ scalars: [Unicode.Scalar], from start: Int) -> Int? {
            var characters: [Unicode.Scalar] = []
            var ends: [Int] = []
            var index = start
            while index < scalars.count, characters.count < ibanLength.upperBound {
                if isLetterOrDigit(scalars[index]) {
                    characters.append(scalars[index])
                    index += 1
                    ends.append(index)
                } else if scalars[index] == " ", index + 1 < scalars.count, isLetterOrDigit(scalars[index + 1]) {
                    index += 1
                } else {
                    break
                }
            }
            guard characters.count >= ibanLength.lowerBound else { return nil }
            for length in stride(from: characters.count, through: ibanLength.lowerBound, by: -1)
            where mod97(characters[..<length]) == 1 {
                return ends[length - 1]
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
