import IOKit.ps

// Public (documented) IOKit power-source API — no private frameworks needed.
func currentBatteryPercent() -> Int? {
    guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
    else {
        return nil
    }

    for source in sources {
        guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
            .takeUnretainedValue() as? [String: AnyObject]
        else {
            continue
        }

        guard let current = description[kIOPSCurrentCapacityKey] as? Int,
              let max = description[kIOPSMaxCapacityKey] as? Int,
              max > 0
        else {
            continue
        }

        return Int((Double(current) / Double(max) * 100.0).rounded())
    }

    return nil
}
