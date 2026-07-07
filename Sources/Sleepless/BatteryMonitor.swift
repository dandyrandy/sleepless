import Foundation
import IOKit.ps

struct BatteryStatus {
    let percent: Int?
    let onACPower: Bool
    let charging: Bool
}

enum BatteryMonitor {
    /// Reads the internal battery via IOKit. Machines without one (or read failures)
    /// report as on AC power so the low-battery auto-off never triggers.
    static func read() -> BatteryStatus {
        let fallback = BatteryStatus(percent: nil, onACPower: true, charging: false)
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return fallback
        }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else {
                continue
            }
            var percent: Int?
            if let current = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                percent = Int((Double(current) / Double(max) * 100).rounded())
            }
            return BatteryStatus(
                percent: percent,
                onACPower: desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                charging: desc[kIOPSIsChargingKey] as? Bool ?? false
            )
        }
        return fallback
    }
}
