import Foundation

/// Parsing of multipart part headers. Everything here works on UTF-8 bytes, not Characters: a
/// combining mark after a `"`, `;`, `=` or `:` would join it into one Character and hide it from
/// the scan, while a server still sees the delimiter.
extension RedactionPolicy {
    /// The `name` and `name*` values of a Content-Disposition value such as
    /// `form-data; name="field"; filename="a.txt"`, in order; a name may appear more than once, as
    /// in `name="a"; name="password"`.
    ///
    /// `nil` when a parameter is malformed (see ``parameters(in:)``) or the name is split over
    /// RFC 2231 continuations (`name*0`, `name*1`, ...): Werkzeug (Flask) joins the pieces, so
    /// `name*0="pass"; name*1="word"` reads as `password`, and a name spread over pieces cannot be
    /// checked piece by piece.
    static func fieldNames(in disposition: String) -> [String]? {
        guard let parameters = parameters(in: disposition) else { return nil }
        guard !parameters.contains(where: { $0.name.hasPrefix("name*") && $0.name != "name*" }) else { return nil }
        return parameters.filter { $0.name == "name" || $0.name == "name*" }.map(\.value)
    }

    /// The parameters of a header value after its first `;`, in order, with lowercased names and
    /// unquoted values; `nil` when one of them is not `token=token` or `token="quoted string"`.
    ///
    /// A malformed parameter is not skipped, because servers skip it in different ways. Werkzeug
    /// (Flask) resumes at the next `;`, even one inside the quotes that follow, so `x ="; name=pw"`
    /// (a space before `=`) and `a@b="; name=pw"` (a key that is not a token) both read as
    /// `name=pw`, and an unclosed quote ends its scan.
    static func parameters(in value: String) -> [(name: String, value: String)]? {
        let bytes = Array(value.utf8)
        // Skip the disposition type.
        guard var index = bytes.firstIndex(of: semicolonByte) else { return [] }
        var parameters: [(name: String, value: String)] = []
        while true {
            while index < bytes.count, bytes[index] == semicolonByte || isSpaceOrTab(bytes[index]) { index += 1 }
            guard index < bytes.count else { return parameters }
            let keyStart = index
            while index < bytes.count, isTokenByte(bytes[index]) { index += 1 }
            let keyEnd = index
            guard keyEnd > keyStart, keyEnd < bytes.count, bytes[keyEnd] == equalsSignByte,
                  let (parameterValue, valueEnd) = parameterValue(in: bytes, at: keyEnd + 1)
            else { return nil }
            index = valueEnd
            while index < bytes.count, isSpaceOrTab(bytes[index]) { index += 1 }
            guard index == bytes.count || bytes[index] == semicolonByte else { return nil }
            parameters.append((String(decoding: bytes[keyStart..<keyEnd], as: UTF8.self).lowercased(), parameterValue))
        }
    }

    /// The token or quoted string that starts at `start`, unquoted, and the index after it; `nil`
    /// when there is neither, or the closing quote is missing.
    private static func parameterValue(in bytes: [UInt8], at start: Int) -> (String, Int)? {
        guard start < bytes.count else { return nil }
        var index = start
        guard bytes[index] == quotationMarkByte else {
            while index < bytes.count, isTokenByte(bytes[index]) { index += 1 }
            return index > start ? (String(decoding: bytes[start..<index], as: UTF8.self), index) : nil
        }
        index += 1
        var unquoted: [UInt8] = []
        while index < bytes.count {
            switch bytes[index] {
            case quotationMarkByte:
                return (String(decoding: unquoted, as: UTF8.self), index + 1)
            case backslashByte where index + 1 < bytes.count:
                unquoted.append(bytes[index + 1])
                index += 2
            default:
                unquoted.append(bytes[index])
                index += 1
            }
        }
        return nil
    }

    /// RFC 9110 token characters: ASCII letters, digits and ``!#$%&'*+-.^_`|~``.
    static func isTokenByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"):
            true
        default:
            tokenSymbols.contains(byte)
        }
    }

    private static let tokenSymbols = Set("!#$%&'*+-.^_`|~".utf8)

    static func isSpaceOrTab(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09
    }

    private static let semicolonByte = UInt8(ascii: ";")
    private static let equalsSignByte = UInt8(ascii: "=")
    private static let quotationMarkByte = UInt8(ascii: "\"")
    private static let backslashByte = UInt8(ascii: "\\")
}
