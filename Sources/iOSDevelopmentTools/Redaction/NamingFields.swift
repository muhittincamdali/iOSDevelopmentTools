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

    /// Two positions are enough to tell whether a field other than a given one is among them.
    private static let keptPositions = 2

    /// The positions of the first two fields that name a secret, and of the first two of those that
    /// hide every other field. Whether a field other than the one being written does is then told
    /// in constant time: reading every naming field again for every field made a form or an object
    /// of many `name=Ayşe` quadratic, about two seconds a megabyte and four times that at two.
    private let naming: [Int]
    private let hidingEveryField: [Int]

    /// Whether any field names a secret in its value.
    var hasNamingField: Bool { !naming.isEmpty }

    /// Reads the fields one at a time, in order.
    init(_ fields: some Sequence<Field>, policy: RedactionPolicy, compatibility: CompatibilityText) {
        var naming: [Int] = []
        var hidingEveryField: [Int] = []
        for (index, (name, value)) in fields.enumerated() {
            let hidesEveryField: Bool
            switch value {
            case .string(let text):
                guard WrittenName.namesSecret(text, in: .field(name), policy: policy, compatibility: compatibility) else { continue }
                hidesEveryField = !WrittenName.mayBeRecordValue(text, field: name, policy: policy, compatibility: compatibility)
            case .structure:
                guard WrittenName.holdsName(name) else { continue }
                hidesEveryField = true
            case .other:
                continue
            }
            if naming.count < Self.keptPositions { naming.append(index) }
            if hidesEveryField, hidingEveryField.count < Self.keptPositions { hidingEveryField.append(index) }
        }
        self.naming = naming
        self.hidingEveryField = hidingEveryField
    }

    /// Whether the value of field `index` is hidden because another field names a secret. The
    /// field is made again only then.
    func hidesValue(at index: Int, of field: @autoclosure () -> Field) -> Bool {
        guard naming.contains(where: { $0 != index }) else { return false }
        let (name, value) = field()
        if WrittenName.carriesValue(name) { return true }
        guard hidingEveryField.contains(where: { $0 != index }) else { return false }
        guard case .string(let text) = value else { return true }
        return !WrittenName.staysBesideName(name, value: text)
    }
}
