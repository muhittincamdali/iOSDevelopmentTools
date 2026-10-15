import Darwin
import Foundation

/// Facts about the app, the device and the process at one moment, for bug reports.
///
/// ```swift
/// let report = DeviceSnapshot.current().report()
/// ```
///
/// Everything is read from public APIs (`Bundle`, `ProcessInfo`, `sysctl`, `task_info`); nothing
/// needs a permission or an entitlement.
public struct DeviceSnapshot: Sendable, Hashable {
    /// One labeled value, as shown in the console's Device tab.
    public struct Row: Sendable, Hashable, Identifiable {
        public let label: String
        public let value: String
        public var id: String { label }
    }

    public let date: Date
    /// `CFBundleDisplayName`, or `CFBundleName` when there is no display name.
    public let appName: String?
    /// `CFBundleShortVersionString`.
    public let appVersion: String?
    /// `CFBundleVersion`.
    public let buildNumber: String?
    public let bundleIdentifier: String?
    /// The OS name and version, such as `iOS 27.0.1`.
    public let operatingSystem: String
    /// The model identifier, such as `iPhone18,1` or `Mac16,10`. In the simulator it is the
    /// identifier of the simulated device.
    public let hardwareModel: String
    public let isSimulator: Bool
    public let processorCount: Int
    /// Installed memory in bytes.
    public let physicalMemory: UInt64
    /// Memory the app uses in bytes, the figure Xcode's memory gauge and jetsam use
    /// (`phys_footprint`), or `nil` when the system does not report it.
    public let memoryFootprint: UInt64?
    public let thermalState: ProcessInfo.ThermalState
    public let isLowPowerModeEnabled: Bool
    /// Whether a debugger such as LLDB is attached to the process.
    public let isDebuggerAttached: Bool
    public let localeIdentifier: String
    public let timeZoneIdentifier: String
    public let preferredLanguages: [String]
    /// Seconds since the device started.
    public let systemUptime: TimeInterval

    /// Creates a snapshot from known values, for previews and tests.
    public init(
        date: Date, appName: String?, appVersion: String?, buildNumber: String?, bundleIdentifier: String?,
        operatingSystem: String, hardwareModel: String, isSimulator: Bool, processorCount: Int,
        physicalMemory: UInt64, memoryFootprint: UInt64?, thermalState: ProcessInfo.ThermalState,
        isLowPowerModeEnabled: Bool, isDebuggerAttached: Bool, localeIdentifier: String,
        timeZoneIdentifier: String, preferredLanguages: [String], systemUptime: TimeInterval
    ) {
        self.date = date
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.bundleIdentifier = bundleIdentifier
        self.operatingSystem = operatingSystem
        self.hardwareModel = hardwareModel
        self.isSimulator = isSimulator
        self.processorCount = processorCount
        self.physicalMemory = physicalMemory
        self.memoryFootprint = memoryFootprint
        self.thermalState = thermalState
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.isDebuggerAttached = isDebuggerAttached
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.preferredLanguages = preferredLanguages
        self.systemUptime = systemUptime
    }

    /// Reads the current values.
    ///
    /// - Parameter bundle: The bundle to read the app's name and version from.
    public static func current(bundle: Bundle = .main) -> DeviceSnapshot {
        let info = ProcessInfo.processInfo
        let environment = info.environment
        let simulatorModel = environment["SIMULATOR_MODEL_IDENTIFIER"]
        return DeviceSnapshot(
            date: Date(),
            appName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            bundleIdentifier: bundle.bundleIdentifier,
            operatingSystem: operatingSystemDescription(info.operatingSystemVersion),
            hardwareModel: simulatorModel ?? hardwareModelIdentifier() ?? "unknown",
            isSimulator: simulatorModel != nil,
            processorCount: info.activeProcessorCount,
            physicalMemory: info.physicalMemory,
            memoryFootprint: currentMemoryFootprint(),
            thermalState: info.thermalState,
            isLowPowerModeEnabled: info.isLowPowerModeEnabled,
            isDebuggerAttached: debuggerIsAttached(),
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier,
            preferredLanguages: Locale.preferredLanguages,
            systemUptime: info.systemUptime
        )
    }

    /// The values as labeled rows, with sizes and durations formatted for `locale`.
    public func rows(locale: Locale = .current) -> [Row] {
        let missing = "–"
        var rows = [
            Row(label: "App", value: appName ?? missing),
            Row(label: "Version", value: [appVersion, buildNumber.map { "(\($0))" }].compactMap { $0 }.joined(separator: " ").nonEmpty ?? missing),
            Row(label: "Bundle identifier", value: bundleIdentifier ?? missing),
            Row(label: "System", value: operatingSystem),
            Row(label: "Model", value: isSimulator ? "\(hardwareModel) (Simulator)" : hardwareModel),
            Row(label: "Processors", value: "\(processorCount)"),
            Row(label: "Memory", value: Self.bytes(physicalMemory, locale: locale)),
            Row(label: "App memory", value: memoryFootprint.map { Self.bytes($0, locale: locale) } ?? missing),
            Row(label: "Thermal state", value: Self.label(for: thermalState)),
            Row(label: "Low Power Mode", value: isLowPowerModeEnabled ? "On" : "Off"),
            Row(label: "Debugger", value: isDebuggerAttached ? "Attached" : "Not attached"),
            Row(label: "Locale", value: localeIdentifier),
            Row(label: "Time zone", value: timeZoneIdentifier),
            Row(label: "Languages", value: preferredLanguages.prefix(5).joined(separator: ", ").nonEmpty ?? missing),
        ]
        rows.append(Row(label: "Uptime", value: Self.duration(systemUptime, locale: locale)))
        return rows
    }

    /// The snapshot as plain text, one `label: value` line per row, preceded by the time it was taken.
    public func report(locale: Locale = .current) -> String {
        let header = "Snapshot taken \(date.formatted(Date.ISO8601FormatStyle()))"
        return ([header] + rows(locale: locale).map { "\($0.label): \($0.value)" }).joined(separator: "\n")
    }

    // MARK: Formatting

    static func bytes(_ count: UInt64, locale: Locale) -> String {
        let clamped = Int64(clamping: count)
        return clamped.formatted(.byteCount(style: .memory).locale(locale))
    }

    /// Seconds as days, hours and minutes; `–` for a value that is not finite or negative.
    static func duration(_ seconds: TimeInterval, locale: Locale) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "–" }
        // Duration traps on values beyond about 1.7e20 seconds, so clamp far below that
        // (a million years). Whole minutes are enough for an uptime.
        let minutes = (min(seconds, 3.2e13) / 60).rounded(.down)
        return Duration.seconds(minutes * 60).formatted(
            .units(allowed: [.days, .hours, .minutes], width: .abbreviated, zeroValueUnits: .hide).locale(locale))
    }

    static func label(for state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }

    static func operatingSystemDescription(_ version: OperatingSystemVersion) -> String {
        #if os(iOS)
        let name = ProcessInfo.processInfo.isiOSAppOnMac ? "iOS (on Mac)" : "iOS"
        #elseif os(macOS)
        let name = "macOS"
        #else
        let name = "OS"
        #endif
        let patch = version.patchVersion > 0 ? ".\(version.patchVersion)" : ""
        return "\(name) \(version.majorVersion).\(version.minorVersion)\(patch)"
    }

    // MARK: System calls

    /// `hw.machine` on iOS devices (`iPhone18,1`), `hw.model` on Macs (`Mac16,10`).
    static func hardwareModelIdentifier() -> String? {
        #if os(macOS)
        let names = ["hw.model", "hw.machine"]
        #else
        let names = ["hw.machine", "hw.model"]
        #endif
        for name in names {
            if let value = sysctlString(name), !value.isEmpty { return value }
        }
        return nil
    }

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0, size <= 1024 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    static func currentMemoryFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }

    static func debuggerIsAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, UInt32(name.count), &info, &size, nil, 0) == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
