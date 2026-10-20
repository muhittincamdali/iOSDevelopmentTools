#if os(macOS)
import Darwin
import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Whether the tests run in an optimized build: memory is measured as shipped, with
/// `swift test -c release`.
private var isOptimized: Bool {
    #if DEBUG
    false
    #else
    true
    #endif
}

/// The peak memory that redacting a megabyte of free text takes. Each input is redacted in a child
/// process of its own (an exit test), so no other test runs beside it, on a thread with a 512 KiB
/// stack. The free-text rule keeps only its position and the cut, so beyond the input it needs a
/// scanning copy of the text, the findings and the output. Exit tests run on macOS only.
@Suite("Redaction: peak memory", .enabled(if: isOptimized, "memory is measured in a release build: swift test -c release"))
struct RedactionMemoryTests {
    static let megabyte = 1_048_576
    static let budget = 16 * megabyte

    @Test("a megabyte of log lines with no trigger takes less than 16 MB beyond its input")
    func textWithoutTrigger() async {
        await #expect(processExitsWith: .success) {
            let input = String(repeating: "status=200 user=bob path=/api/items count=3\n", count: RedactionMemoryTests.megabyte / 44)
            RedactionMemoryTests.exitWithPeak { _ = RedactionPolicy.default.redact(text: input) }
        }
    }

    @Test("a megabyte cut at its first line takes less than 16 MB beyond its input")
    func textCutEarly() async {
        await #expect(processExitsWith: .success) {
            let input = "login password=hunter2\n" + String(repeating: "status=200 user=bob path=/api/items count=3\n", count: RedactionMemoryTests.megabyte / 44)
            RedactionMemoryTests.exitWithPeak { _ = RedactionPolicy.default.redact(text: input) }
        }
    }

    @Test("a megabyte of JSON and URLs in log lines takes less than 16 MB beyond its input")
    func textWithDocuments() async {
        await #expect(processExitsWith: .success) {
            let line = "got {\"status\":200,\"items\":[1,2,3]} from https://api.example.com/v1/items?page=2\n"
            let input = String(repeating: line, count: RedactionMemoryTests.megabyte / line.utf8.count)
            RedactionMemoryTests.exitWithPeak { _ = RedactionPolicy.default.redact(text: input) }
        }
    }

    @Test("a megabyte of email addresses, each a finding, takes less than 16 MB beyond its input")
    func textWithManyFindings() async {
        await #expect(processExitsWith: .success) {
            let input = String(repeating: "a@b.co ", count: RedactionMemoryTests.megabyte / 7)
            RedactionMemoryTests.exitWithPeak { _ = RedactionPolicy.default.redact(text: input) }
        }
    }

    /// Runs `work` on a thread with a 512 KiB stack and exits with success when the peak memory
    /// footprint of the process grew by less than ``budget`` over what it was before. The peak is
    /// at least the footprint before plus what `work` took, so the check never passes a run that
    /// took more.
    static func exitWithPeak(_ work: @escaping @Sendable () -> Void) -> Never {
        guard let before = footprint() else { exit(EXIT_FAILURE) }
        onThread(stackSize: 512 * 1024, work)
        guard let after = footprint() else { exit(EXIT_FAILURE) }
        exit(after.peak - before.current < budget ? EXIT_SUCCESS : EXIT_FAILURE)
    }

    /// The physical footprint of the process and its peak, in bytes.
    static func footprint() -> (current: Int, peak: Int)? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        return (Int(info.phys_footprint), Int(info.ledger_phys_footprint_peak))
    }
}
#endif
