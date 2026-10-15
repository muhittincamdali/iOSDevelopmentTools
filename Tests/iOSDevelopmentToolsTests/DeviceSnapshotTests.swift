import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Device snapshot")
struct DeviceSnapshotTests {
    let english = Locale(identifier: "en_US_POSIX")

    private func snapshot(uptime: TimeInterval = 93_784, footprint: UInt64? = 150_000_000, simulator: Bool = false) -> DeviceSnapshot {
        DeviceSnapshot(
            date: Date(timeIntervalSince1970: 0), appName: "Demo", appVersion: "2.0", buildNumber: "41",
            bundleIdentifier: "io.example.demo", operatingSystem: "iOS 27.0", hardwareModel: "iPhone18,1",
            isSimulator: simulator, processorCount: 6, physicalMemory: 8 * 1024 * 1024 * 1024,
            memoryFootprint: footprint, thermalState: .fair, isLowPowerModeEnabled: true,
            isDebuggerAttached: false, localeIdentifier: "en_US", timeZoneIdentifier: "Europe/Istanbul",
            preferredLanguages: ["en-US", "tr-TR"], systemUptime: uptime)
    }

    @Test("Rows show every value with readable units")
    func rows() {
        let rows = Dictionary(uniqueKeysWithValues: snapshot().rows(locale: english).map { ($0.label, $0.value) })
        #expect(rows["App"] == "Demo")
        #expect(rows["Version"] == "2.0 (41)")
        #expect(rows["Model"] == "iPhone18,1")
        #expect(rows["Memory"] == "8 GB")
        #expect(rows["App memory"] == "143.1 MB")
        #expect(rows["Thermal state"] == "Fair")
        #expect(rows["Low Power Mode"] == "On")
        #expect(rows["Debugger"] == "Not attached")
        #expect(rows["Languages"] == "en-US, tr-TR")
        #expect(rows["Uptime"] == "1 day, 2 hr, 3 min")
    }

    @Test("Missing values and the simulator are labeled")
    func missingValues() {
        let empty = DeviceSnapshot(
            date: Date(), appName: nil, appVersion: nil, buildNumber: nil, bundleIdentifier: nil,
            operatingSystem: "macOS 27.0", hardwareModel: "iPhone18,1", isSimulator: true, processorCount: 1,
            physicalMemory: 0, memoryFootprint: nil, thermalState: .critical, isLowPowerModeEnabled: false,
            isDebuggerAttached: true, localeIdentifier: "", timeZoneIdentifier: "UTC", preferredLanguages: [],
            systemUptime: 0)
        let rows = Dictionary(uniqueKeysWithValues: empty.rows(locale: english).map { ($0.label, $0.value) })
        #expect(rows["App"] == "–")
        #expect(rows["Version"] == "–")
        #expect(rows["App memory"] == "–")
        #expect(rows["Languages"] == "–")
        #expect(rows["Model"] == "iPhone18,1 (Simulator)")
        #expect(rows["Debugger"] == "Attached")
        #expect(rows["Thermal state"] == "Critical")
    }

    @Test("Durations that cannot be shown do not trap", arguments: [
        (Double.nan, "–"), (Double.infinity, "–"), (-1, "–"), (59, "0 min"), (1e300, nil), (Double.greatestFiniteMagnitude, nil),
    ] as [(Double, String?)])
    func extremeDurations(seconds: Double, expected: String?) {
        let text = DeviceSnapshot.duration(seconds, locale: english)
        if let expected {
            #expect(text == expected)
        } else {
            #expect(text.hasPrefix("370370370 days"))
        }
    }

    @Test("Byte counts beyond Int64 are clamped instead of trapping")
    func hugeByteCounts() {
        #expect(!DeviceSnapshot.bytes(.max, locale: english).isEmpty)
        #expect(DeviceSnapshot.bytes(0, locale: english) == "Zero kB")
    }

    @Test("The report has a header and one line per row")
    func report() {
        let report = snapshot().report(locale: english)
        let lines = report.split(separator: "\n")
        #expect(lines.first == "Snapshot taken 1970-01-01T00:00:00Z")
        #expect(lines.count == snapshot().rows(locale: english).count + 1)
        #expect(lines.contains("System: iOS 27.0"))
    }

    @Test("The current snapshot matches what the system reports")
    func current() throws {
        let current = DeviceSnapshot.current()
        let info = ProcessInfo.processInfo
        #expect(current.processorCount == info.activeProcessorCount)
        #expect(current.physicalMemory == info.physicalMemory)
        #expect(current.operatingSystem.contains("\(info.operatingSystemVersion.majorVersion).\(info.operatingSystemVersion.minorVersion)"))
        let footprint = try #require(current.memoryFootprint)
        #expect(footprint > 1_000_000)
        #expect(current.hardwareModel != "unknown")
        #expect(current.isSimulator == (info.environment["SIMULATOR_MODEL_IDENTIFIER"] != nil))
        #expect(current.systemUptime > 0)
        #expect(current.timeZoneIdentifier == TimeZone.current.identifier)
    }

    @Test("sysctl reads known names and rejects unknown ones")
    func sysctl() {
        #expect(DeviceSnapshot.sysctlString("kern.ostype") == "Darwin")
        #expect(DeviceSnapshot.sysctlString("no.such.name") == nil)
    }
}
