import Foundation

/// The text of a body, a part or a part's headers, decoded the same way on every OS version.
///
/// `String(data:encoding:)` leaves out a byte order mark at the start of the bytes on some OS
/// versions (iOS 26.5, macOS 27) and keeps it as U+FEFF on others (iOS 18.6), so the same body
/// was read as other text. Here the bytes are decoded with every byte order mark kept, and the
/// one at the start is left out only where the caller asks for it.
enum BodyText {
    /// The byte order mark of UTF-8, which RFC 8259 lets a JSON parser and RFC 3629 lets a
    /// reader of UTF-8 text ignore at the start.
    static let utf8ByteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]

    /// The text of UTF-8 bytes; nil when they are not UTF-8. With `dropsByteOrderMark`, one byte
    /// order mark at the start is left out; every other one is kept as U+FEFF.
    static func utf8(_ bytes: some Collection<UInt8>, dropsByteOrderMark: Bool) -> String? {
        let hasMark = dropsByteOrderMark && bytes.starts(with: utf8ByteOrderMark)
        let content = bytes[(hasMark ? bytes.index(bytes.startIndex, offsetBy: utf8ByteOrderMark.count) : bytes.startIndex)...]
        // Decoding keeps every U+FEFF but replaces bytes that are not UTF-8 with U+FFFD, which
        // writes other bytes than were read.
        let text = String(decoding: content, as: UTF8.self)
        return text.utf8.elementsEqual(content) ? text : nil
    }

    /// The text of a JSON body in `encoding`, with the byte order mark of that encoding at its
    /// start left out; nil when the bytes are not in that encoding. A text in UTF-16 or UTF-32 is
    /// decoded by Foundation, and is nil when that left out another byte order mark, which a
    /// version that keeps it reads as U+FEFF, where JSON allows none.
    static func json(_ body: Data, in encoding: String.Encoding) -> String? {
        if encoding == .utf8 { return utf8(body, dropsByteOrderMark: true) }
        let mark = byteOrderMarks[encoding] ?? []
        let content = body.starts(with: mark) ? body.dropFirst(mark.count) : body
        let unitSize = encoding == .utf16LittleEndian || encoding == .utf16BigEndian ? 2 : 4
        guard let text = String(data: content, encoding: encoding) else { return nil }
        let units = unitSize == 2 ? text.utf16.count : text.unicodeScalars.count
        return units * unitSize == content.count ? text : nil
    }

    private static let byteOrderMarks: [String.Encoding: [UInt8]] = [
        .utf16BigEndian: [0xFE, 0xFF], .utf16LittleEndian: [0xFF, 0xFE],
        .utf32BigEndian: [0, 0, 0xFE, 0xFF], .utf32LittleEndian: [0xFF, 0xFE, 0, 0],
    ]
}
