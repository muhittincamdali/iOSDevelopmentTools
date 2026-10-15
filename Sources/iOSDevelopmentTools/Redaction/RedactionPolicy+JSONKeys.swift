import Foundation

/// The duplicate key check for JSON. Parsers disagree about an object that repeats a key:
/// JSONSerialization keeps one value, Python's `json` module and JavaScript's `JSON.parse` keep
/// the last. Only the value JSONSerialization keeps is checked, so a body that repeats a key could
/// carry a secret past the check to a server that reads the other value.
extension RedactionPolicy {
    /// Whether no object in `json` has two keys that are the same string; `false` as well when the
    /// text cannot be scanned. `json` must be text that JSONSerialization accepted.
    ///
    /// Keys are compared after their escapes are decoded, so `"a"` and `"a"` are the same
    /// key, and as Swift strings, which treat canonically equivalent strings (`é` and `e` followed
    /// by U+0301) as equal. That is the loosest comparison any of the parsers above makes.
    static func hasUniqueKeys(json: Data) -> Bool {
        guard let bytes = utf8Bytes(ofJSON: json) else { return false }
        // The keys of every open object, and `nil` for every open array.
        var containers: [Set<String>?] = []
        var expectsKey = false
        var index = 0
        while index < bytes.count {
            switch bytes[index] {
            case UInt8(ascii: "{"):
                containers.append([])
                expectsKey = true
            case UInt8(ascii: "["):
                containers.append(nil)
                expectsKey = false
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                guard containers.popLast() != nil else { return false }
                expectsKey = false
            case UInt8(ascii: ","):
                expectsKey = containers.last.map { $0 != nil } ?? false
            case UInt8(ascii: "\""):
                guard let (string, end) = jsonString(in: bytes, at: index) else { return false }
                if expectsKey, let last = containers.indices.last {
                    guard containers[last]?.insert(string).inserted == true else { return false }
                    expectsKey = false
                }
                index = end
                continue
            default:
                break
            }
            index += 1
        }
        return containers.isEmpty
    }

    /// The JSON text as UTF-8. JSONSerialization also reads UTF-16 and UTF-32, after a byte order
    /// mark or, without one, by the pattern of zero bytes in the first four (RFC 4627), so such
    /// text is converted first; a UTF-8 text never holds a zero byte.
    private static func utf8Bytes(ofJSON json: Data) -> [UInt8]? {
        if let encoding = wideEncoding(of: json) ?? wideEncodingWithoutByteOrderMark(of: json) {
            return String(data: json, encoding: encoding).map { Array($0.utf8) }
        }
        guard String(data: json, encoding: .utf8) != nil else { return nil }
        return Array(json)
    }

    private static func wideEncodingWithoutByteOrderMark(of json: Data) -> String.Encoding? {
        guard json.contains(0) else { return nil }
        let head = Array(json.prefix(4)) + [UInt8](repeating: 1, count: 4)
        switch (head[0], head[1], head[2], head[3]) {
        case (0, 0, 0, _): return .utf32BigEndian
        case (0, _, _, _): return .utf16BigEndian
        case (_, 0, 0, 0): return .utf32LittleEndian
        case (_, 0, _, _): return .utf16LittleEndian
        default: return nil
        }
    }

    /// The decoded string that starts with the quote at `start`, and the index after its closing
    /// quote; `nil` when an escape is malformed or the closing quote is missing. An escaped lone
    /// surrogate reads as U+FFFD.
    private static func jsonString(in bytes: [UInt8], at start: Int) -> (String, Int)? {
        var decoded: [UInt8] = []
        var index = start + 1
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "\"") { return (String(decoding: decoded, as: UTF8.self), index + 1) }
            guard byte == UInt8(ascii: "\\") else {
                decoded.append(byte)
                index += 1
                continue
            }
            guard index + 1 < bytes.count else { return nil }
            let escaped = bytes[index + 1]
            if escaped == UInt8(ascii: "u") {
                guard let (scalar, end) = unicodeEscape(in: bytes, at: index) else { return nil }
                UTF8.encode(scalar) { decoded.append($0) }
                index = end
                continue
            }
            guard let character = simpleEscapes[escaped] else { return nil }
            decoded.append(character)
            index += 2
        }
        return nil
    }

    private static let simpleEscapes: [UInt8: UInt8] = [
        UInt8(ascii: "\""): UInt8(ascii: "\""), UInt8(ascii: "\\"): UInt8(ascii: "\\"),
        UInt8(ascii: "/"): UInt8(ascii: "/"), UInt8(ascii: "b"): 0x08, UInt8(ascii: "f"): 0x0C,
        UInt8(ascii: "n"): 0x0A, UInt8(ascii: "r"): 0x0D, UInt8(ascii: "t"): 0x09,
    ]

    /// The scalar of the `\uXXXX` escape at `start`, joined with a following low surrogate escape
    /// when it is a high surrogate, and the index after it.
    private static func unicodeEscape(in bytes: [UInt8], at start: Int) -> (Unicode.Scalar, Int)? {
        guard let unit = hexUnit(in: bytes, at: start + 2) else { return nil }
        let end = start + 6
        if (0xD800...0xDBFF).contains(unit), end + 1 < bytes.count,
           bytes[end] == UInt8(ascii: "\\"), bytes[end + 1] == UInt8(ascii: "u"),
           let low = hexUnit(in: bytes, at: end + 2), (0xDC00...0xDFFF).contains(low) {
            let value = 0x10000 + ((UInt32(unit) - 0xD800) << 10) + (UInt32(low) - 0xDC00)
            return (Unicode.Scalar(value) ?? "\u{FFFD}", end + 6)
        }
        return (Unicode.Scalar(UInt32(unit)) ?? "\u{FFFD}", end)
    }

    /// The four hexadecimal digits at `start` as a UTF-16 code unit.
    private static func hexUnit(in bytes: [UInt8], at start: Int) -> UInt16? {
        guard start + 4 <= bytes.count else { return nil }
        var unit: UInt16 = 0
        for byte in bytes[start..<start + 4] {
            guard let digit = Character(Unicode.Scalar(byte)).hexDigitValue else { return nil }
            unit = unit << 4 | UInt16(digit)
        }
        return unit
    }
}
