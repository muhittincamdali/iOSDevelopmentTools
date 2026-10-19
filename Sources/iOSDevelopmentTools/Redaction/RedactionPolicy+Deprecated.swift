import Foundation

/// The 2.0.0 names, kept so code written against them still builds. They map to the current
/// rules, which hide at least as much: the default secret names cannot be removed, and a body
/// that cannot be parsed is always omitted.
extension RedactionPolicy {
    @available(*, deprecated, renamed: "defaultSecretNames")
    public static var defaultNameFragments: [String] { defaultSecretNames }

    @available(*, deprecated, renamed: "secretNames")
    public var nameFragments: Set<String> { secretNames }

    /// Always `true` for an enabled policy: a body that cannot be parsed is omitted.
    @available(*, deprecated, message: "Bodies that cannot be parsed are always omitted.")
    public var withholdsUncheckedBodies: Bool { isEnabled }

    /// A policy with the default secret names and `nameFragments` added to them.
    ///
    /// `withholdsUncheckedBodies` is ignored: a body that cannot be parsed is always omitted. Use
    /// ``disabled`` to store everything unchanged.
    @available(*, deprecated, renamed: "init(additionalSecretNames:allowedHeaders:allowedQueryParameters:urlDetail:)")
    public init(nameFragments: some Sequence<String>, withholdsUncheckedBodies: Bool = true) {
        self.init(additionalSecretNames: Array(nameFragments))
    }

    /// The default policy; `withholdsUncheckedBodies` is ignored, as above.
    @available(*, deprecated, message: "Bodies that cannot be parsed are always omitted; use RedactionPolicy().")
    public init(withholdsUncheckedBodies: Bool) {
        self.init()
    }
}

extension RedactionOutcome {
    @available(*, deprecated, renamed: "omitted")
    public static var withheld: RedactionOutcome { .omitted }
}
