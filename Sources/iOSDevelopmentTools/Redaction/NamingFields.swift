/// The fields of an object, a form, a URL query or a multipart body that name a secret in their
/// value, and which other fields that hides.
///
/// Beside such a name, a field that carries the value of a pair (see
/// ``WrittenName/carriesValue(_:)``) is hidden whole, wherever it is written: the fields have no
/// order. Beside a name that names a secret word, has no letter or digit, or is held by a field
/// that only pairs use (`label`, `key`, `param`, …), every other field is hidden as well, apart
/// from the names of pairs and a JSON Patch or SCIM `op` (see
/// ``WrittenName/staysBesideName(_:value:)``): what belongs to that name cannot be told. A name
/// under `name`, `id` or `type` that is only written outside plain ASCII may be a person, a place,
/// a product or a media type (see ``WrittenName/mayBeRecordValue(_:field:policy:compatibility:)``),
/// so beside it only the fields that carry a value are hidden and the rest of the record stays
/// readable (`{"id":42,"name":"Ayşe Yılmaz","price":12.5}`).
struct NamingFields {
    enum Value {
        case string([Unicode.Scalar])
        /// An object or an array, which a field that holds a name cannot hold as a name.
        case structure
        /// A number, `true`, `false`, `null`, or no value at all.
        case other
    }

    /// A field: its name, and its value as the rule reads it.
    typealias Field = (name: [Unicode.Scalar], value: Value)

    /// The positions of the fields that name a secret, and whether each hides every other field or
    /// only those that carry a value. Only these are kept, so a body of many fields is not held a
    /// second time as Unicode scalars.
    private let naming: [(index: Int, hidesEveryField: Bool)]

    /// Whether any field names a secret in its value.
    var hasNamingField: Bool { !naming.isEmpty }

    /// Reads the fields one at a time, in order.
    init(_ fields: some Sequence<Field>, policy: RedactionPolicy, compatibility: CompatibilityText) {
        var naming: [(index: Int, hidesEveryField: Bool)] = []
        for (index, (name, value)) in fields.enumerated() {
            switch value {
            case .string(let text):
                guard WrittenName.namesSecret(text, in: .field(name), policy: policy, compatibility: compatibility) else { continue }
                let isRecordValue = WrittenName.mayBeRecordValue(text, field: name, policy: policy, compatibility: compatibility)
                naming.append((index, !isRecordValue))
            case .structure:
                if WrittenName.holdsName(name) { naming.append((index, true)) }
            case .other:
                continue
            }
        }
        self.naming = naming
    }

    /// Whether the value of field `index` is hidden because another field names a secret. The
    /// field is made again only then.
    func hidesValue(at index: Int, of field: @autoclosure () -> Field) -> Bool {
        let others = naming.lazy.filter { $0.index != index }
        guard !others.isEmpty else { return false }
        let (name, value) = field()
        if WrittenName.carriesValue(name) { return true }
        guard others.contains(where: \.hidesEveryField) else { return false }
        guard case .string(let text) = value else { return true }
        return !WrittenName.staysBesideName(name, value: text)
    }
}
