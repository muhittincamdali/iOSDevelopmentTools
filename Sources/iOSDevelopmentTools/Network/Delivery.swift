import Foundation

/// A block that can be scheduled on another thread's run loop with `perform(_:on:with:waitUntilDone:modes:)`.
final class Delivery: NSObject, @unchecked Sendable {
    private let block: () -> Void

    init(_ block: @escaping () -> Void) {
        self.block = block
    }

    @objc func run() {
        block()
    }
}
