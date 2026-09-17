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

func cmdEnable() {
    withSMC {
        guard SMCComm.Charging.enableCharging() else {
            fail("failed to enable charging")
        }
        log("charging enabled")
    }
}

func cmdDisable() {
    withSMC {
        guard SMCComm.Charging.disableCharging() else {
            fail("failed to disable charging")
        }
        log("charging disabled")
    }
}

func cmdStatus() {
    withSMC {
        guard let disabled = SMCComm.Charging.isChargingDisabled() else {
            fail("failed to read charging state")
        }
        log(disabled ? "charging is disabled" : "charging is enabled")
    }
}

// Self-healing mode: derive the desired state from the current wall-clock
// hour instead of trusting that this specific invocation was the "right"
// scheduled fire. Used for both the daily 4pm/9pm triggers and RunAtLoad,
// so a missed firing (e.g. asleep at 4pm) is corrected the next time the
// daemon starts, and the Mac can never get stuck permanently unable to
// charge just because one scheduled event didn't run.
func cmdAuto() {
    let hour = Calendar.current.component(.hour, from: Date())
    let blockedWindow = 16..<23
    if blockedWindow.contains(hour) {
        cmdDisable()
    } else {
        cmdEnable()
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
