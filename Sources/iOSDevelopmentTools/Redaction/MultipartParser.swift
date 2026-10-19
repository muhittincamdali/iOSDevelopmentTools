import Foundation

/// Splits a multipart body into its parts, on UTF-8 bytes, as strictly as RFC 2046 reads it.
///
/// Servers read malformed multipart in different ways, and a part that a server reads where this
/// parser reads none could carry a secret past the check. So anything that servers could read
/// differently makes the whole body unparsed: a boundary that is not a token or quoted string of
/// RFC 2046 characters or is given twice, a delimiter after a bare CR or LF, a line that starts
/// with the boundary and goes on, text before the first or after the closing delimiter, a missing
/// closing delimiter, or more than ``maximumParts`` parts.
enum MultipartParser {
    /// A body with more parts than this is not parsed; the parts are kept in memory.
    static let maximumParts = 1_000

    /// One part: the bytes of its header lines (CRLF-separated, without the blank line) and of
    /// its content.
    struct Part {
        let headers: Data
        let content: Data
    }

    /// The `boundary` parameter of a multipart content type, without quotes; `nil` when there is
    /// none, more than one (also counting `boundary*`), the parameters are malformed, or the
    /// value is not 1 to 70 RFC 2046 boundary characters.
    static func boundary(in contentType: String) -> String? {
        guard let boundaries = RedactionPolicy.parameters(in: contentType)?.filter({ $0.name.hasPrefix("boundary") }),
              boundaries.count == 1, let boundary = boundaries.first, boundary.name == "boundary"
        else { return nil }
        let value = boundary.value.utf8
        guard (1...70).contains(value.count), value.last != UInt8(ascii: " "), value.allSatisfy(isBoundaryByte) else { return nil }
        return boundary.value
    }

    /// RFC 2046 `bchars`: ASCII letters, digits, space and `'()+_,-./:=?`.
    private static func isBoundaryByte(_ byte: UInt8) -> Bool {
        ValueDetectors.isLetterOrDigit(Unicode.Scalar(byte)) || boundarySymbols.contains(byte)
    }

    private static let boundarySymbols = Set(" '()+_,-./:=?".utf8)

    /// The parts of the body, or `nil` when it does not have the structure RFC 2046 describes.
    static func parts(of body: Data, boundary: String) -> [Part]? {
        let delimiter = Data("--\(boundary)".utf8)
        guard let delimiters = delimiterRanges(of: delimiter, in: body),
              let first = delimiters.first,
              body[body.startIndex..<first.lowerBound].allSatisfy(isLinearWhitespace)
        else { return nil }
        var parts: [Part] = []
        for (position, found) in delimiters.enumerated() {
            let end = position + 1 < delimiters.count ? delimiters[position + 1].lowerBound : body.endIndex
            let rest = body[found.upperBound..<end]
            if rest.starts(with: Data("--".utf8)) {
                // The closing delimiter: only white space may follow it.
                return rest.dropFirst(2).allSatisfy(isLinearWhitespace) && position == delimiters.count - 1 ? parts : nil
            }
            guard let part = part(in: rest) else { return nil }
            parts.append(part)
        }
        return nil
    }

    /// The delimiters that start a line; `nil` when one follows a bare CR or LF, is followed by
    /// anything but `--` or optional spaces and a CRLF, or there are too many.
    private static func delimiterRanges(of delimiter: Data, in body: Data) -> [Range<Data.Index>]? {
        var delimiters: [Range<Data.Index>] = []
        var searchStart = body.startIndex
        while let found = body.range(of: delimiter, in: searchStart..<body.endIndex) {
            switch linePosition(of: found.lowerBound, in: body) {
            case .insideLine:
                searchStart = body.index(after: found.lowerBound)
                continue
            case .afterBareLineBreak:
                return nil
            case .lineStart:
                break
            }
            guard endsDelimiter(at: found.upperBound, in: body), delimiters.count <= maximumParts else { return nil }
            delimiters.append(found)
            searchStart = found.upperBound
        }
        return delimiters
    }

    /// A part from the bytes after its delimiter: the rest of the delimiter line, header lines,
    /// a blank line and the content, which ends with the CRLF before the next delimiter.
    private static func part(in rest: Data.SubSequence) -> Part? {
        let lineBreak = Data("\r\n".utf8)
        guard let headerEnd = rest.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerBytes = rest[rest.startIndex..<headerEnd.lowerBound]
        guard !containsBareLineBreak(headerBytes), rest.count >= 2, rest.suffix(2).elementsEqual(lineBreak),
              headerEnd.upperBound <= rest.endIndex - 2
        else { return nil }
        return Part(headers: Data(headerBytes), content: Data(rest[headerEnd.upperBound..<(rest.endIndex - 2)]))
    }

    /// Space, tab, CR or LF.
    static func isLinearWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == carriageReturn || byte == lineFeed
    }

    /// Whether the bytes after a delimiter are `--`, which closes the body, or optional spaces and
    /// tabs followed by a CRLF, the only two endings RFC 2046 allows.
    private static func endsDelimiter(at index: Data.Index, in body: Data) -> Bool {
        let rest = body[index...]
        if rest.starts(with: Data("--".utf8)) { return true }
        return rest.drop(while: { $0 == 0x20 || $0 == 0x09 }).starts(with: Data("\r\n".utf8))
    }

    private enum LinePosition {
        /// The start of the body, or after a CRLF.
        case lineStart
        /// After a CR or LF that is not part of a CRLF; servers such as Werkzeug split there.
        case afterBareLineBreak
        case insideLine
    }

    private static func linePosition(of index: Data.Index, in body: Data) -> LinePosition {
        guard index != body.startIndex else { return .lineStart }
        let previous = body[body.index(before: index)]
        if previous == lineFeed, body.distance(from: body.startIndex, to: index) >= 2,
           body[body.index(index, offsetBy: -2)] == carriageReturn {
            return .lineStart
        }
        return previous == lineFeed || previous == carriageReturn ? .afterBareLineBreak : .insideLine
    }

    /// Whether `bytes` hold a CR or LF that is not part of a CRLF; a server that splits header
    /// lines there could end the headers earlier than the first blank CRLF line.
    private static func containsBareLineBreak(_ bytes: Data.SubSequence) -> Bool {
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            let next = bytes.index(after: index)
            if byte == carriageReturn {
                guard next < bytes.endIndex, bytes[next] == lineFeed else { return true }
                index = bytes.index(after: next)
                continue
            }
            if byte == lineFeed { return true }
            index = next
        }
        return false
    }

    private static let carriageReturn: UInt8 = 0x0D
    private static let lineFeed: UInt8 = 0x0A
}
