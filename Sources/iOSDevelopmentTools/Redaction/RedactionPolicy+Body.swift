import Foundation

/// What redaction did to a stored body.
public enum RedactionOutcome: String, Sendable, Hashable, Codable {
    /// Nothing sensitive was found, or the body is not a kind that is checked.
    case unchanged
    /// One or more sensitive values were replaced.
    case redacted
    /// The body looked structured but could not be checked, so it was not stored.
    case withheld
}

extension RedactionPolicy {
    /// Nested JSON deeper than this is withheld instead of walked.
    static let maximumJSONDepth = 64
    /// A multipart body with more parts than this is withheld; the parts are tracked in memory,
    /// and a body of nothing but delimiters would otherwise need millions of them.
    static let maximumMultipartParts = 1_000

    /// The body with sensitive values replaced.
    ///
    /// JSON bodies (by content type, or because they start with `{` or `[`, whatever their content
    /// type says) have the values of sensitive keys replaced at any depth. Form bodies (`application/x-www-form-urlencoded`) and
    /// multipart bodies (`multipart/form-data`) have the values of sensitive fields replaced. A
    /// body without a content type is checked as a form, because `URLSession` sends it as one.
    /// Other bodies are returned unchanged.
    ///
    /// - Parameters:
    ///   - body: The bytes to check.
    ///   - contentType: The `Content-Type` header value, if any.
    ///   - isComplete: `false` when `body` holds only the first part of a longer body.
    public func redact(body: Data, contentType: String?, isComplete: Bool = true) -> (body: Data, outcome: RedactionOutcome) {
        redact(body: body, contentType: contentType, isComplete: isComplete, nesting: 0)
    }

    private func redact(body: Data, contentType: String?, isComplete: Bool, nesting: Int) -> (body: Data, outcome: RedactionOutcome) {
        guard isEnabled, !body.isEmpty else { return (body, .unchanged) }
        let mediaType = contentType?.lowercased() ?? ""
        let withheld = (Data(), RedactionOutcome.withheld)
        let unchecked = withholdsUncheckedBodies ? withheld : (body, .unchanged)

        if mediaType.contains("multipart/") {
            // A multipart part may itself be multipart; one level of nesting is checked.
            guard isComplete, nesting < 2, let boundary = Self.boundary(in: contentType ?? ""),
                  let result = redact(multipart: body, boundary: boundary, nesting: nesting) else { return unchecked }
            return result
        }
        // JSON comes before forms: a JSON body sent with a form content type reads as one field
        // with no "=" and would be stored unchecked, with every key in it.
        if mediaType.contains("json") || Self.looksLikeJSON(body) {
            guard isComplete, let result = redact(json: body) else { return unchecked }
            return result
        }
        if mediaType.contains("x-www-form-urlencoded") {
            guard let text = String(data: body, encoding: .utf8) else { return unchecked }
            let redacted = redact(parameters: Substring(text))
            return redacted == text ? (body, .unchanged) : (Data(redacted.utf8), .redacted)
        }
        if contentType == nil {
            // URLSession sends a body without a Content-Type as application/x-www-form-urlencoded.
            // Bytes that are not UTF-8 cannot hide a field name, so they are decoded leniently.
            let text = String(decoding: body, as: UTF8.self)
            let redacted = redact(parameters: Substring(text))
            return redacted == text ? (body, .unchanged) : (Data(redacted.utf8), .redacted)
        }
        return (body, .unchanged)
    }

    private static func looksLikeJSON(_ body: Data) -> Bool {
        // JSONSerialization also reads UTF-16 and UTF-32 after their byte order marks, so such a
        // body is decoded before its first character is looked at.
        if let encoding = wideEncoding(of: body) {
            guard let text = String(data: body, encoding: encoding) else { return false }
            let first = text.unicodeScalars.first { $0 != "\u{FEFF}" && !$0.properties.isWhitespace }
            return first == "{" || first == "["
        }
        // A UTF-8 byte order mark may come first; JSONSerialization reads past it.
        let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]
        let text = body.starts(with: byteOrderMark) ? body.dropFirst(byteOrderMark.count) : body[...]
        guard let first = text.first(where: { !isLinearWhitespace($0) }) else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    /// UTF-16 or UTF-32 when the body starts with one of their byte order marks. The UTF-32
    /// little-endian mark starts like the UTF-16 one, so it is tested first.
    private static func wideEncoding(of body: Data) -> String.Encoding? {
        if body.starts(with: [0xFF, 0xFE, 0x00, 0x00]) || body.starts(with: [0x00, 0x00, 0xFE, 0xFF]) { return .utf32 }
        if body.starts(with: [0xFF, 0xFE]) || body.starts(with: [0xFE, 0xFF]) { return .utf16 }
        return nil
    }

    // MARK: JSON

    private func redact(json body: Data) -> (Data, RedactionOutcome)? {
        guard let object = try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed]) else {
            return nil
        }
        guard let (redacted, changed) = redact(jsonValue: object, depth: 0) else { return nil }
        guard changed else { return (body, .unchanged) }
        // data(withJSONObject:) raises an Objective-C exception, which Swift cannot catch, for
        // objects it cannot encode (such as an infinite number), so check first.
        guard JSONSerialization.isValidJSONObject(redacted),
              let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys, .withoutEscapingSlashes])
        else { return nil }
        return (data, .redacted)
    }

    /// The value with sensitive keys replaced, and whether anything changed; `nil` when the
    /// nesting is too deep to check.
    private func redact(jsonValue: Any, depth: Int) -> (Any, Bool)? {
        guard depth <= Self.maximumJSONDepth else { return nil }
        if let dictionary = jsonValue as? [String: Any] {
            var result: [String: Any] = [:]
            var changed = false
            for (key, value) in dictionary {
                if isSensitive(name: key) {
                    result[key] = Self.replacement
                    changed = true
                } else {
                    guard let (child, childChanged) = redact(jsonValue: value, depth: depth + 1) else { return nil }
                    result[key] = child
                    changed = changed || childChanged
                }
            }
            return (result, changed)
        }
        if let array = jsonValue as? [Any] {
            var result: [Any] = []
            result.reserveCapacity(array.count)
            var changed = false
            for element in array {
                guard let (child, childChanged) = redact(jsonValue: element, depth: depth + 1) else { return nil }
                result.append(child)
                changed = changed || childChanged
            }
            return (result, changed)
        }
        if let string = jsonValue as? String {
            return redact(embeddedJSON: string, depth: depth)
        }
        return (jsonValue, false)
    }

    /// A string value that holds JSON itself, as GraphQL clients often send `variables`, with
    /// sensitive keys replaced inside it. Other strings are returned as they are.
    private func redact(embeddedJSON string: String, depth: Int) -> (Any, Bool)? {
        let data = Data(string.utf8)
        guard Self.looksLikeJSON(data),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is [String: Any] || object is [Any]
        else { return (string, false) }
        guard let (redacted, changed) = redact(jsonValue: object, depth: depth + 1) else { return nil }
        guard changed else { return (string, false) }
        guard JSONSerialization.isValidJSONObject(redacted),
              let encoded = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys, .withoutEscapingSlashes])
        else { return nil }
        return (String(decoding: encoded, as: UTF8.self), true)
    }

    // MARK: Multipart

    /// The `boundary` parameter of a multipart content type, without quotes; `nil` when there is
    /// none, more than one, or the content type's parameters are malformed.
    ///
    /// Servers differ in which of two boundary parameters they use (Werkzeug, behind Flask, takes
    /// the last), and parts delimited by the other one would be read but not checked. An RFC 2231
    /// `boundary*` parameter counts as another one, because a server that reads it may prefer it.
    /// The parameters are read as in a Content-Disposition (see ``parameters(in:)``): Werkzeug
    /// reads `boundary=B1/x` as `B1`, and would find parts at `--B1` lines that sit inside the
    /// parts checked here. The value must also consist of RFC 2046 boundary characters, which
    /// leaves out the `%22` that Werkzeug turns into a quote.
    static func boundary(in contentType: String) -> String? {
        guard let boundaries = parameters(in: contentType)?.filter({ $0.name.hasPrefix("boundary") }),
              boundaries.count == 1, let boundary = boundaries.first, boundary.name == "boundary"
        else { return nil }
        // RFC 2046: 1 to 70 characters, the last of which is not a space.
        let value = boundary.value.utf8
        guard (1...70).contains(value.count), value.last != UInt8(ascii: " "),
              value.allSatisfy(isBoundaryByte) else { return nil }
        return boundary.value
    }

    /// RFC 2046 `bchars`: ASCII letters, digits, space and `'()+_,-./:=?`.
    private static func isBoundaryByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"):
            true
        default:
            boundarySymbols.contains(byte)
        }
    }

    private static let boundarySymbols = Set(" '()+_,-./:=?".utf8)

    /// The multipart body with the content of sensitive fields replaced; `nil` when the body does
    /// not have the structure its content type promises.
    private func redact(multipart body: Data, boundary: String, nesting: Int) -> (Data, RedactionOutcome)? {
        let delimiter = Data("--\(boundary)".utf8)
        let headerEnd = Data("\r\n\r\n".utf8)
        let lineBreak = Data("\r\n".utf8)
        var delimiters: [Range<Data.Index>] = []
        var searchStart = body.startIndex
        while let found = body.range(of: delimiter, in: searchStart..<body.endIndex) {
            // RFC 2046: a delimiter starts a line. "--boundary" inside a line is content; taking it
            // for a delimiter would let a part end early, and a server would still read the parts
            // that follow it.
            switch Self.linePosition(of: found.lowerBound, in: body) {
            case .insideLine:
                searchStart = body.index(after: found.lowerBound)
                continue
            case .afterBareLineBreak:
                // RFC 2046 lines end in CRLF, but Werkzeug (Flask) and other servers also split
                // on a bare LF and would read a part that starts there, so it cannot be content.
                return nil
            case .lineStart:
                break
            }
            // "--boundaryX" is not a delimiter in RFC 2046, but a server that compares only the
            // prefix would start a part there, so such a line cannot be kept as content either.
            guard Self.endsDelimiter(at: found.upperBound, in: body) else { return nil }
            // The closing delimiter is one more than the parts.
            guard delimiters.count <= Self.maximumMultipartParts else { return nil }
            delimiters.append(found)
            searchStart = found.upperBound
        }
        guard !delimiters.isEmpty else { return nil }
        // Servers ignore the preamble before the first delimiter and the epilogue after the
        // closing one, but both would be stored as they are. Only line breaks are kept there.
        let preamble = body[body.startIndex..<delimiters[0].lowerBound]
        guard preamble.allSatisfy(Self.isLinearWhitespace) else { return nil }

        var output = Data(preamble)
        var changed = false
        var closed = false
        for (position, found) in delimiters.enumerated() {
            output.append(delimiter)
            let partEnd = position + 1 < delimiters.count ? delimiters[position + 1].lowerBound : body.endIndex
            let part = body[found.upperBound..<partEnd]
            if part.starts(with: Data("--".utf8)) {
                let epilogue = body[body.index(found.upperBound, offsetBy: 2)...]
                guard epilogue.allSatisfy(Self.isLinearWhitespace) else { return nil }
                output.append(body[found.upperBound...])
                closed = true
                break
            }
            guard let headersRange = part.range(of: headerEnd),
                  !Self.containsBareLineBreak(part[part.startIndex..<headersRange.lowerBound]),
                  let headers = Self.partHeaders(part[part.startIndex..<headersRange.lowerBound])
            else { return nil }
            // Servers differ in which of several Content-Disposition headers, or of several name
            // parameters, they read, so every one is checked.
            var names: [String] = []
            for disposition in headers["content-disposition"] ?? [] {
                guard let dispositionNames = Self.fieldNames(in: disposition) else { return nil }
                names += dispositionNames
            }
            // Likewise, a part with two content types could be read as either.
            let partTypes = headers["content-type"] ?? []
            guard partTypes.count <= 1 else { return nil }
            let hasLineBreak = part.count >= 2 && part.suffix(2).elementsEqual(lineBreak)
            let contentEnd = hasLineBreak ? part.index(part.endIndex, offsetBy: -2) : part.endIndex
            let content = Data(part[headersRange.upperBound..<contentEnd])
            output.append(part[part.startIndex..<headersRange.upperBound])
            if names.contains(where: isSensitive(name:)) {
                output.append(Data(Self.replacement.utf8))
                changed = true
            } else {
                // A part that is not sensitive by name may still be JSON, a form or multipart.
                // A part without a Content-Type is text/plain (RFC 7578), not a form.
                let partType = partTypes.first ?? "text/plain"
                let (checked, outcome) = redact(body: content, contentType: partType, isComplete: true, nesting: nesting + 1)
                if outcome == .withheld { return nil }
                output.append(checked)
                changed = changed || outcome == .redacted
            }
            if hasLineBreak { output.append(lineBreak) }
        }
        guard closed else { return nil }
        return changed ? (output, .redacted) : (body, .unchanged)
    }

    /// Space, tab, CR or LF.
    private static func isLinearWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0D || byte == 0x0A
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
        /// After a CR or LF that is not part of a CRLF.
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

    /// Whether `bytes` hold a CR or LF that is not part of a CRLF. Servers that split part
    /// headers on a bare LF could end the headers, and start the content, earlier than the
    /// first blank CRLF line.
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
