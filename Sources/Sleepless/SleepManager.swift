import Foundation
import SleeplessCore

enum SleepManager {
    static let helperPath = "/usr/local/libexec/sleepless-helper"

    static var helperInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: helperPath)
    }

    /// Flips the system-wide `pmset disablesleep` switch via the root helper.
    /// Uses `sudo -n` so it fails fast (instead of hanging) if the sudoers rule is missing.
    static func setSleepDisabled(_ disabled: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", helperPath, disabled ? "on" : "off"]).status == 0
    }

    static func isSleepDisabled() -> Bool {
        let result = run("/usr/bin/pmset", ["-g"])
        guard result.status == 0 else { return false }
        return parseSleepDisabled(result.output)
    }

    /// One-time privileged install of the helper + sudoers rule.
    /// Shows the standard macOS administrator-password dialog via osascript.
    static func installHelper() -> Bool {
        guard let dir = helperSourceDirectory() else { return false }
        let script = dir.appendingPathComponent("install-helper.sh").path
        let command = "/bin/sh \(shellQuoted(script)) \(shellQuoted(NSUserName()))"
        let osa = "do shell script \"\(appleScriptEscaped(command))\" with administrator privileges"
        return run("/usr/bin/osascript", ["-e", osa]).status == 0
    }

    // MARK: - Private

    /// The install scripts live in the app bundle's Resources; fall back to ./helper
    /// so `swift run` from the repo also works during development.
    private static func helperSourceDirectory() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources)
        }
        candidates.append(URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("helper"))
        return candidates.first { fm.fileExists(atPath: $0.appendingPathComponent("install-helper.sh").path) }
    }

    private static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return (-1, "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    private static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
