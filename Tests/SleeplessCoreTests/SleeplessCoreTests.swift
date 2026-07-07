import XCTest
import SleeplessCore

final class ParseSleepDisabledTests: XCTestCase {
    // Real `pmset -g` output from a machine where disablesleep has never been set:
    // no SleepDisabled line at all.
    private let untouchedOutput = [
        "System-wide power settings:",
        " DestroyFVKeyOnStandby\t\t1",
        "Currently in use:",
        " standby              1",
        " Sleep On Power Button 1",
        " sleep                1 (sleep prevented by caffeinate, powerd)",
        " displaysleep         15",
    ].joined(separator: "\n")

    func testAbsentLineMeansSleepEnabled() {
        XCTAssertFalse(parseSleepDisabled(untouchedOutput))
    }

    func testTabSeparatedValueOne() {
        let output = [
            "System-wide power settings:",
            " DestroyFVKeyOnStandby\t\t1",
            " SleepDisabled\t\t1",
            "Currently in use:",
            " sleep                1",
        ].joined(separator: "\n")
        XCTAssertTrue(parseSleepDisabled(output))
    }

    func testTabSeparatedValueZero() {
        let output = [
            "System-wide power settings:",
            " SleepDisabled\t\t0",
            "Currently in use:",
        ].joined(separator: "\n")
        XCTAssertFalse(parseSleepDisabled(output))
    }

    func testSpaceSeparatedValueOne() {
        XCTAssertTrue(parseSleepDisabled(" SleepDisabled 1"))
    }

    func testKeyWithoutValue() {
        XCTAssertFalse(parseSleepDisabled(" SleepDisabled"))
    }

    func testSimilarlyNamedKeyDoesNotMatch() {
        XCTAssertFalse(parseSleepDisabled(" NotSleepDisabled 1\n SleepDisabledExtra 1"))
    }

    func testEmptyOutput() {
        XCTAssertFalse(parseSleepDisabled(""))
    }
}

final class BatteryAutoOffTests: XCTestCase {
    func testDischargingBelowThreshold() {
        let battery = BatteryStatus(percent: 10, onACPower: false, charging: false)
        XCTAssertTrue(battery.shouldAutoOff(belowPercent: 15))
    }

    func testDischargingAtThreshold() {
        let battery = BatteryStatus(percent: 15, onACPower: false, charging: false)
        XCTAssertTrue(battery.shouldAutoOff(belowPercent: 15))
    }

    func testDischargingAboveThreshold() {
        let battery = BatteryStatus(percent: 16, onACPower: false, charging: false)
        XCTAssertFalse(battery.shouldAutoOff(belowPercent: 15))
    }

    func testLowButOnACPower() {
        let battery = BatteryStatus(percent: 5, onACPower: true, charging: true)
        XCTAssertFalse(battery.shouldAutoOff(belowPercent: 15))
    }

    func testUnknownPercentNeverTriggers() {
        let battery = BatteryStatus(percent: nil, onACPower: false, charging: false)
        XCTAssertFalse(battery.shouldAutoOff(belowPercent: 15))
    }
}

final class FormatIntervalTests: XCTestCase {
    func testMinutesOnly() {
        XCTAssertEqual(formatInterval(45 * 60), "45 min")
    }

    func testExactHour() {
        XCTAssertEqual(formatInterval(3600), "1 h 0 min")
    }

    func testHoursAndMinutes() {
        XCTAssertEqual(formatInterval(2 * 3600 + 90), "2 h 1 min")
    }

    func testSubMinuteRoundsDownToZero() {
        XCTAssertEqual(formatInterval(29), "0 min")
    }
}
