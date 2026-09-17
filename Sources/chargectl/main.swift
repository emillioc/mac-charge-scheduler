import Foundation

func timestamp() -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: Date())
}

func log(_ message: String) {
    print("[\(timestamp())] \(message)")
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("[\(timestamp())] error: \(message)\n".data(using: .utf8)!)
    exit(1)
}

func withSMC<T>(_ body: () -> T) -> T {
    guard SMCComm.start() else {
        fail("could not open AppleSMC")
    }
    defer { SMCComm.stop() }

    guard SMCComm.Charging.supported() else {
        fail("no supported charge-control SMC key found on this machine")
    }

    return body()
}

// These assume an SMC session is already open (called from within withSMC).
func doEnable() {
    guard SMCComm.Charging.enableCharging() else {
        fail("failed to enable charging")
    }
    log("charging enabled")
}

func doDisable() {
    guard SMCComm.Charging.disableCharging() else {
        fail("failed to disable charging")
    }
    log("charging disabled")
}

func doStatus() -> Bool {
    guard let disabled = SMCComm.Charging.isChargingDisabled() else {
        fail("failed to read charging state")
    }
    log(disabled ? "charging is disabled" : "charging is enabled")
    return disabled
}

func cmdEnable() {
    withSMC { doEnable() }
}

func cmdDisable() {
    withSMC { doDisable() }
}

func cmdStatus() {
    withSMC { _ = doStatus() }
}

// Battery-percent safety valve, only meaningful while inside the blocked
// window. Uses the SMC key's own current state as the hysteresis memory
// (no separate state file needed): below the low threshold, allow charging
// from the grid; above the high threshold, go back to blocking (running on
// battery); in between, leave whatever the current state already is.
let lowThreshold = 15
let highThreshold = 30

func applyThreshold() {
    guard let percent = currentBatteryPercent() else {
        fail("failed to read battery percentage")
    }

    if percent < lowThreshold {
        log("battery \(percent)% is below \(lowThreshold)%, overriding block to charge from grid")
        doEnable()
    } else if percent > highThreshold {
        log("battery \(percent)% is above \(highThreshold)%, resuming block (running on battery)")
        doDisable()
    } else {
        let disabled = doStatus()
        log("battery \(percent)% is within the \(lowThreshold)-\(highThreshold)% band, leaving charging \(disabled ? "disabled" : "enabled")")
    }
}

// Self-healing mode: derive the desired state from the current wall-clock
// hour instead of trusting that this specific invocation was the "right"
// scheduled fire. Runs on the daily 4pm/11pm triggers, the periodic
// battery-check interval, and RunAtLoad, so a missed firing (e.g. asleep at
// 4pm) is corrected the next time the daemon starts, and the Mac can never
// get stuck permanently unable to charge just because one scheduled event
// didn't run.
func cmdAuto() {
    withSMC {
        let hour = Calendar.current.component(.hour, from: Date())
        let blockedWindow = 16..<23
        if blockedWindow.contains(hour) {
            applyThreshold()
        } else {
            doEnable()
        }
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fail("usage: chargectl <enable|disable|status|auto>")
}

switch arguments[1] {
case "enable":
    cmdEnable()
case "disable":
    cmdDisable()
case "status":
    cmdStatus()
case "auto":
    cmdAuto()
default:
    fail("unknown command '\(arguments[1])' (expected enable|disable|status|auto)")
}
