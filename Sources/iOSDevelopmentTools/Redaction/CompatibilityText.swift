import Foundation

/// Reads a scalar outside ASCII as the ASCII it stands for under Unicode compatibility
/// decomposition (NFKD) without its marks: `ａ` and `𝐚` are `a`, `é` is `e`, `＝` and `︓` are `=`
/// and `:`, `≠` is `=`, a digit of any script is its digit, a dash of any kind is `-`, every space
/// is ` ` and a line or paragraph separator is `\n`. A scalar whose decomposition is not ASCII is
/// read as ``unreadable``. This is Unicode's own mapping, not a list of look-alikes: a Cyrillic
/// `а` stays unreadable.
///
/// What a scalar is read as is worked out once, from one normalization, and kept in a table, as
/// logs repeat the same few non-ASCII characters and the normalization goes through Foundation.
/// The table is direct-mapped: its size is fixed when it is made, about one slot for each scalar
/// of the input it serves (a text cannot hold more different scalars than that), from
/// ``fewestSlots`` to ``mostSlots``, and it never grows. A scalar's slot is chosen by
/// multiply-shift hashing with an odd multiplier drawn at random for each table, so no text can
/// choose scalars that meet in a slot (two scalars meet with a chance of at most two in the number
/// of slots); a scalar that meets another takes the slot over. A reading keeps
/// its bytes in place (see ``Reading``), so a slot takes 24 bytes whatever a text holds, and the
/// table is made only when the first scalar outside ASCII is read. One table serves a whole text,
/// body, URL or list of headers, with every field, part, segment and header in it.
///
/// The seventeenth review measured 15 MiB of cached readings for a megabyte of different scalars:
/// a dictionary kept one for each, each with an array of its own, and a second dictionary
/// normalized every scalar again. Every form field, multipart part, path segment, query value and
/// header also made a table of its own.
final class CompatibilityText {
    /// A byte that no detector or separator matches.
    static let unreadable: UInt8 = 0xFF

    /// What a scalar outside ASCII is read as, found from one normalization: its ASCII reading,
    /// whether its compatibility form leaves the safe alphabet of free text (see
    /// ``formLeavesSafeAlphabet(_:)``) and whether the decomposition alone reads it as ASCII (see
    /// ``foldsToASCII(_:)``). Up to four bytes of the reading are kept in place, which is as long
    /// as a reading is in Unicode today (a test reads every scalar); a longer one would be kept in
    /// an array.
    struct Reading: Equatable {
        /// The first four bytes of the reading, the first in the low byte.
        private let packed: UInt32
        private let length: UInt8
        let leavesSafeAlphabet: Bool
        let foldsToASCII: Bool
        /// The reading when it is longer than four bytes.
        private let long: [UInt8]?

        init(bytes: [UInt8], leavesSafeAlphabet: Bool, foldsToASCII: Bool) {
            var packed: UInt32 = 0
            for (k, byte) in bytes.prefix(4).enumerated() { packed |= UInt32(byte) << (8 * k) }
            self.packed = packed
            length = UInt8(clamping: bytes.count)
            long = bytes.count > 4 ? bytes : nil
            self.leavesSafeAlphabet = leavesSafeAlphabet
            self.foldsToASCII = foldsToASCII
        }

        var bytes: Bytes { Bytes(packed: packed, count: Int(length), long: long) }

        /// The bytes of a reading, read where they are kept.
        struct Bytes: RandomAccessCollection {
            fileprivate let packed: UInt32
            let count: Int
            fileprivate let long: [UInt8]?

            fileprivate init(packed: UInt32, count: Int, long: [UInt8]?) {
                self.packed = packed
                self.count = count
                self.long = long
            }

            /// One ASCII byte.
            init(ascii byte: UInt8) {
                self.init(packed: UInt32(byte), count: 1, long: nil)
            }

            var startIndex: Int { 0 }
            var endIndex: Int { count }

            subscript(position: Int) -> UInt8 {
                if let long { return long[position] }
                return UInt8(truncatingIfNeeded: packed >> (8 * position))
            }
        }
    }

    /// The sizes of a table: slots for a text of a few scalars, and for a text, body, URL or list
    /// of headers of 4,096 scalars or more (96 KiB).
    static let fewestSlots = 16
    static let mostSlots = 4_096

    private struct Slot {
        /// The scalar whose reading the slot holds; 0, which is ASCII, when it holds none.
        var scalar: UInt32
        var reading: Reading
    }

    private static let emptySlot = Slot(scalar: 0, reading: Reading(bytes: [], leavesSafeAlphabet: true, foldsToASCII: false))

    /// The number of slots, a power of two, fixed when the table is made.
    private let size: Int
    /// The multiplier of the hash, odd, and the shift that keeps its top bits as the slot.
    private let multiplier: UInt64
    private let shift: UInt64
    /// Empty until the first scalar outside ASCII is read, so ASCII text makes no table.
    private var slots: [Slot] = []

    /// The slots of the table, for the tests: 0 until a scalar outside ASCII is read.
    var slotCount: Int { slots.count }
    /// How many readings were worked out rather than found in the table, for the tests.
    private(set) var uncachedReadings = 0

    /// - Parameters:
    ///   - length: The number of scalars (or bytes) of the input the table serves.
    ///   - multiplier: The multiplier of the hash; a random one unless a test chooses it.
    init(length: Int = mostSlots, multiplier: UInt64 = .random(in: 0...UInt64.max)) {
        var size = Self.fewestSlots
        while size < length, size < Self.mostSlots { size *= 2 }
        self.size = size
        self.multiplier = multiplier | 1
        shift = UInt64(64 - size.trailingZeroBitCount)
    }

    func ascii(_ scalar: Unicode.Scalar) -> Reading.Bytes {
        if scalar.isASCII { return Reading.Bytes(ascii: UInt8(scalar.value)) }
        return reading(scalar).bytes
    }

    /// Whether compatibility decomposition alone reads the scalar as ASCII (`－` as `-`, `＝` as
    /// `=`), without the readings this type adds to it: a dash of any kind as `-`, every space as
    /// ` ` and a digit of any script as its digit.
    func foldsToASCII(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isASCII || reading(scalar).foldsToASCII
    }

    /// Whether the compatibility form of a scalar outside ASCII holds a character outside the safe
    /// alphabet of free text: ASCII punctuation (`🄁` is `0,`, `⒈` is `1.`, `⑴` is `(1)`), or a
    /// character outside ASCII that is not a letter, mark or digit (`½` is `1⁄2`). The scanning
    /// copy reads the scalar as that form, so a letter or digit with such a form is outside the
    /// alphabet too (see ``FreeTextScanner/isOutsideSafeAlphabet(_:)``). An ASCII space in the
    /// form is not: a scalar read as a space is judged as one.
    func formLeavesSafeAlphabet(_ scalar: Unicode.Scalar) -> Bool {
        !scalar.isASCII && reading(scalar).leavesSafeAlphabet
    }

    /// The reading of a scalar outside ASCII.
    private func reading(_ scalar: Unicode.Scalar) -> Reading {
        if slots.isEmpty { slots = Array(repeating: Self.emptySlot, count: size) }
        let index = Int(truncatingIfNeeded: (UInt64(scalar.value) &* multiplier) >> shift)
        if slots[index].scalar == scalar.value { return slots[index].reading }
        let reading = Self.read(scalar)
        uncachedReadings += 1
        slots[index] = Slot(scalar: scalar.value, reading: reading)
        return reading
    }

    /// The reading of a scalar: from its compatibility decomposition, or from none for an
    /// ideograph or a Hangul syllable (see ``readsOutsideASCII(_:)``).
    static func read(_ scalar: Unicode.Scalar) -> Reading {
        readsOutsideASCII(scalar) ? outsideASCII : decomposedReading(scalar)
    }

    /// The reading of a scalar from one compatibility decomposition through Foundation.
    static func decomposedReading(_ scalar: Unicode.Scalar) -> Reading {
        let form = String(scalar).decomposedStringWithCompatibilityMapping.unicodeScalars
        let parts = form.filter { !ScalarClass.isInvisible($0) }
        return Reading(
            bytes: read(scalar, parts: parts), leavesSafeAlphabet: form.contains(where: leavesSafeAlphabet),
            foldsToASCII: !parts.isEmpty && parts.allSatisfy(\.isASCII))
    }

    /// Whether a scalar is an ideograph or a Hangul syllable, which is read as ``unreadable``,
    /// inside the safe alphabet and not as ASCII, without asking Foundation: an ideograph has no
    /// decomposition or one to another ideograph, and a syllable decomposes to Hangul letters.
    /// They are most of the different characters a text can hold, so a text of more of them than
    /// its table has slots (a megabyte of Chinese) does not go through Foundation for each one it
    /// reads again. A test compares this with the decomposition for every such scalar.
    static func readsOutsideASCII(_ scalar: Unicode.Scalar) -> Bool {
        hangulSyllables.contains(scalar.value) || scalar.properties.isIdeographic
    }

    private static let hangulSyllables: ClosedRange<UInt32> = 0xAC00...0xD7A3
    static let outsideASCII = Reading(bytes: [unreadable], leavesSafeAlphabet: false, foldsToASCII: false)

    /// Whether a scalar of a compatibility form is outside the safe alphabet: ASCII other than a
    /// letter, a digit or a space, or a scalar outside ASCII other than a letter, mark or digit.
    private static func leavesSafeAlphabet(_ part: Unicode.Scalar) -> Bool {
        guard part.isASCII else { return !ScalarClass.isLetterOrNumber(part) }
        let byte = UInt8(part.value)
        return !(ASCII.isAlphanumeric(byte) || byte == UInt8(ascii: " "))
    }

    /// The ASCII reading of a scalar, from the visible scalars of its compatibility form.
    private static func read(_ scalar: Unicode.Scalar, parts: String.UnicodeScalarView) -> [UInt8] {
        if let digit = ScalarClass.decimalDigit(scalar) { return [UInt8(ascii: "0") + digit] }
        switch scalar.properties.generalCategory {
        case .lineSeparator, .paragraphSeparator: return [UInt8(ascii: "\n")]
        default: break
        }
        if scalar == "\u{85}" { return [UInt8(ascii: "\n")] }
        // The blank Braille pattern draws nothing, like a space.
        if scalar.properties.isWhitespace || scalar == "\u{2800}" { return [UInt8(ascii: " ")] }
        if scalar.properties.generalCategory == .dashPunctuation { return [UInt8(ascii: "-")] }
        var bytes: [UInt8] = []
        for part in parts {
            guard part.isASCII else { return [unreadable] }
            bytes.append(UInt8(part.value))
        }
        return bytes.isEmpty ? [unreadable] : bytes
    }
}
