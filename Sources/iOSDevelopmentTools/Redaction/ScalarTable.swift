/// The Unicode properties that the readers of keys, free text and values ask of a scalar: its
/// general category, and whether it is a variation selector, a default-ignorable code point, an
/// emoji or an emoji modifier.
///
/// They are looked up once for every scalar of the Basic Multilingual Plane, the first time any is
/// asked for, and shared: asking the standard library for them takes two lookups per property, and
/// text in another script asks for the same few scalars at every level of a document quoted in a
/// document. Scalars outside the plane, which are rare in logs, are looked up each time.
enum ScalarTable {
    private static let categories: [Unicode.GeneralCategory] = [
        .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .nonspacingMark, .spacingMark,
        .enclosingMark, .decimalNumber, .letterNumber, .otherNumber, .connectorPunctuation, .dashPunctuation, .openPunctuation,
        .closePunctuation, .initialPunctuation, .finalPunctuation, .otherPunctuation, .mathSymbol, .currencySymbol, .modifierSymbol,
        .otherSymbol, .spaceSeparator, .lineSeparator, .paragraphSeparator, .control, .format, .surrogate, .privateUse, .unassigned,
    ]

    private static let categoryMask: UInt16 = 0x1F
    private static let variationSelector: UInt16 = 1 << 5
    private static let defaultIgnorable: UInt16 = 1 << 6
    private static let emoji: UInt16 = 1 << 7
    private static let emojiModifier: UInt16 = 1 << 8

    private static let basicPlaneEnd: UInt32 = 0x1_0000

    /// 128 KiB: two bytes for each scalar of the plane.
    private static let basicPlane: [UInt16] = (0..<basicPlaneEnd).map { value in
        guard let scalar = Unicode.Scalar(value) else { return UInt16(categories.firstIndex(of: .surrogate) ?? 0) }
        return entry(scalar)
    }

    private static func entry(_ scalar: Unicode.Scalar) -> UInt16 {
        let properties = scalar.properties
        var bits = UInt16(categories.firstIndex(of: properties.generalCategory) ?? categories.count - 1)
        if properties.isVariationSelector { bits |= variationSelector }
        if properties.isDefaultIgnorableCodePoint { bits |= defaultIgnorable }
        if properties.isEmoji { bits |= emoji }
        if properties.isEmojiModifier { bits |= emojiModifier }
        return bits
    }

    private static func bits(_ scalar: Unicode.Scalar) -> UInt16 {
        scalar.value < basicPlaneEnd ? basicPlane[Int(scalar.value)] : entry(scalar)
    }

    static func category(_ scalar: Unicode.Scalar) -> Unicode.GeneralCategory {
        categories[Int(bits(scalar) & categoryMask)]
    }

    static func isVariationSelector(_ scalar: Unicode.Scalar) -> Bool { bits(scalar) & variationSelector != 0 }

    static func isDefaultIgnorable(_ scalar: Unicode.Scalar) -> Bool { bits(scalar) & defaultIgnorable != 0 }

    static func isEmoji(_ scalar: Unicode.Scalar) -> Bool { bits(scalar) & (emoji | emojiModifier) != 0 }
}
