/// Whether the tests run in an optimized build. A debug build runs the redaction code many times
/// slower and measures more memory than the shipped code takes, so the time limits, the memory
/// limits and the largest probe sets are checked with `swift test -c release`.
var isOptimized: Bool {
    #if DEBUG
    false
    #else
    true
    #endif
}
