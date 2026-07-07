import Foundation

public struct BatteryStatus {
    public let percent: Int?
    public let onACPower: Bool
    public let charging: Bool

    public init(percent: Int?, onACPower: Bool, charging: Bool) {
        self.percent = percent
        self.onACPower = onACPower
        self.charging = charging
    }

    /// True when keep-awake should auto-off: discharging at or below the threshold.
    /// Unknown battery level never triggers (machines without a battery report nil).
    public func shouldAutoOff(belowPercent threshold: Int) -> Bool {
        guard let percent, !onACPower else { return false }
        return percent <= threshold
    }
}

/// Parses `pmset -g` output. The SleepDisabled line only appears once the setting
/// has been touched; an absent line means sleep is enabled.
public func parseSleepDisabled(_ pmsetOutput: String) -> Bool {
    for line in pmsetOutput.split(separator: "\n") {
        let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        if fields.first == "SleepDisabled" {
            return fields.last == "1"
        }
    }
    return false
}

/// "1 h 5 min" / "45 min" for menu display.
public func formatInterval(_ interval: TimeInterval) -> String {
    let minutes = Int(interval / 60)
    let (h, m) = (minutes / 60, minutes % 60)
    return h > 0 ? "\(h) h \(m) min" : "\(m) min"
}
