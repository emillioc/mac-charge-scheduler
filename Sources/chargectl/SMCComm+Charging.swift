//
// Adapted from mhaeuser/Battery-Toolkit (Libraries/SMCComm+Power.swift),
// keeping only the charge-enable/disable key (CHTE, falling back to CH0C).
// Copyright (C) 2022 - 2025 Marvin Häuser. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//

extension SMCComm {
    enum Charging {
        private struct KeyControl {
            let keyInfo: SMCComm.KeyInfo
            let onBytes: [UInt8]
            let offBytes: [UInt8]
        }

        private static let chtE = KeyControl(
            keyInfo: SMCComm.KeyInfo(
                key: SMCComm.Key("C", "H", "T", "E"),
                info: SMCComm.KeyInfoData(dataSize: 4, dataType: SMCComm.KeyTypes.ui32, dataAttributes: 0xD4)
            ),
            onBytes: [0x00, 0x00, 0x00, 0x00],
            offBytes: [0x01, 0x00, 0x00, 0x00]
        )
        private static let ch0C = KeyControl(
            keyInfo: SMCComm.KeyInfo(
                key: SMCComm.Key("C", "H", "0", "C"),
                info: SMCComm.KeyInfoData(dataSize: 1, dataType: SMCComm.KeyTypes.hex, dataAttributes: 0xD4)
            ),
            onBytes: [0x00],
            offBytes: [0x01]
        )
        private static let candidates = [chtE, ch0C]

        private static var active: KeyControl?

        static func supported() -> Bool {
            self.active = self.candidates.first { SMCComm.keySupported(keyInfo: $0.keyInfo) }
            return self.active != nil
        }

        static func enableCharging() -> Bool {
            guard let active = self.active else { return false }
            return SMCComm.writeKey(key: active.keyInfo.key, bytes: active.onBytes)
        }

        static func disableCharging() -> Bool {
            guard let active = self.active else { return false }
            return SMCComm.writeKey(key: active.keyInfo.key, bytes: active.offBytes)
        }

        static func isChargingDisabled() -> Bool? {
            guard let active = self.active else { return nil }
            guard let value = SMCComm.readKey(key: active.keyInfo.key, dataSize: active.onBytes.count) else {
                return nil
            }
            return value != active.onBytes
        }
    }
}
