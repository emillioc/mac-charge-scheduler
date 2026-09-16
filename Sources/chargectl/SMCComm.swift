//
// Adapted from mhaeuser/Battery-Toolkit (Libraries/SMCComm.swift).
// Copyright (C) 2022 - 2025 Marvin Häuser. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//

import CSMC
import Darwin
import Foundation
import IOKit
import os

public typealias SMCId = FourCharCode

public extension SMCId {
    init(_ char0: Character, _ char1: Character, _ char2: Character, _ char3: Character) {
        let comp0 = UInt32(char0.asciiValue!) << 24
        let comp1 = UInt32(char1.asciiValue!) << 16
        let comp2 = UInt32(char2.asciiValue!) << 8
        let comp3 = UInt32(char3.asciiValue!)
        self = comp0 | comp1 | comp2 | comp3
    }
}

enum SMCComm {
    typealias Key = SMCId
    typealias KeyType = SMCId
    typealias KeyInfoData = SMCKeyInfoData

    struct KeyInfo {
        let key: SMCComm.Key
        let info: SMCComm.KeyInfoData
    }

    enum KeyTypes {
        static let ui8 = SMCComm.KeyType("u", "i", "8", " ")
        static let ui32 = SMCComm.KeyType("u", "i", "3", "2")
        static let hex = SMCComm.KeyType("h", "e", "x", "_")
    }

    static func keyInfoDataEq(_ data1: SMCComm.KeyInfoData, _ data2: SMCComm.KeyInfoData) -> Bool {
        return data1.dataSize == data2.dataSize &&
            data1.dataType == data2.dataType &&
            data1.dataAttributes == data2.dataAttributes
    }

    private static var connect: io_connect_t = IO_OBJECT_NULL

    static func start() -> Bool {
        let smc = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSMC"))
        guard smc != IO_OBJECT_NULL else {
            return false
        }

        var connect: io_connect_t = IO_OBJECT_NULL
        let resultOpen = IOServiceOpen(smc, mach_task_self_, 1, &connect)
        guard resultOpen == kIOReturnSuccess, connect != IO_OBJECT_NULL else {
            return false
        }

        self.connect = connect
        IOConnectCallMethod(connect, UInt32(kSMCUserClientOpen), nil, 0, nil, 0, nil, nil, nil, nil)

        return true
    }

    static func stop() {
        IOConnectCallMethod(self.connect, UInt32(kSMCUserClientClose), nil, 0, nil, 0, nil, nil, nil, nil)
        IOServiceClose(self.connect)
        self.connect = IO_OBJECT_NULL
    }

    static func getKeyInfo(key: SMCComm.Key) -> SMCComm.KeyInfoData? {
        var inputStruct = SMCParamStruct.info(key: key)
        guard let outputStruct = self.callSMC(params: &inputStruct) else {
            return nil
        }
        return outputStruct.keyInfo
    }

    static func keySupported(keyInfo: SMCComm.KeyInfo) -> Bool {
        guard let info = self.getKeyInfo(key: keyInfo.key),
              self.keyInfoDataEq(keyInfo.info, info) else {
            return false
        }
        return true
    }

    static func readKey(key: SMCComm.Key, dataSize: Int) -> [UInt8]? {
        var inputStruct = SMCParamStruct.readKey(key: key, dataSize: UInt32(dataSize))
        guard let outputStruct = self.callSMC(params: &inputStruct) else {
            return nil
        }

        let mirror = Mirror(reflecting: outputStruct.bytes)
        return mirror.children.prefix(dataSize).map { $0.value as! UInt8 }
    }

    static func writeKey(key: SMCComm.Key, bytes: [UInt8]) -> Bool {
        var inputStruct = SMCParamStruct.writeKey(key: key, bytes: bytes)
        let outputStruct = self.callSMC(params: &inputStruct)

        // Defensive: some SMC keys have reported success while silently
        // keeping their old value, so read back and confirm.
        guard let readValue = self.readKey(key: key, dataSize: bytes.count) else {
            return outputStruct != nil
        }
        return readValue == bytes
    }

    private static func callSMC(params: inout SMCParamStruct) -> SMCParamStruct? {
        assert(self.connect != IO_OBJECT_NULL)
        assert(MemoryLayout<SMCParamStruct>.stride == 80)

        var outputValues = SMCParamStruct()
        var outStructSize = MemoryLayout<SMCParamStruct>.stride

        let resultCall = IOConnectCallStructMethod(
            self.connect,
            UInt32(kSMCHandleYPCEvent),
            &params,
            MemoryLayout<SMCParamStruct>.stride,
            &outputValues,
            &outStructSize
        )
        guard resultCall == kIOReturnSuccess, outputValues.result == UInt8(kSMCSuccess) else {
            FileHandle.standardError.write(
                "SMC error: call=\(resultCall) result=\(outputValues.result)\n".data(using: .utf8)!
            )
            return nil
        }

        return outputValues
    }
}

private extension SMCParamStruct {
    static func info(key: SMCComm.Key) -> SMCParamStruct {
        var paramStruct = SMCParamStruct()
        paramStruct.key = key
        paramStruct.data8 = UInt8(kSMCGetKeyInfo)
        return paramStruct
    }

    static func readKey(key: SMCComm.Key, dataSize: UInt32) -> SMCParamStruct {
        var paramStruct = SMCParamStruct()
        paramStruct.key = key
        paramStruct.keyInfo.dataSize = dataSize
        paramStruct.data8 = UInt8(kSMCReadKey)
        return paramStruct
    }

    static func writeKey(key: SMCComm.Key, bytes: [UInt8]) -> SMCParamStruct {
        var paramStruct = SMCParamStruct()
        precondition(bytes.count < Mirror(reflecting: paramStruct.bytes).children.count)
        paramStruct.key = key
        paramStruct.keyInfo.dataSize = UInt32(bytes.count)
        paramStruct.data8 = UInt8(kSMCWriteKey)
        _ = withUnsafeMutablePointer(to: &paramStruct.bytes) { pointer in
            memcpy(pointer, bytes, bytes.count)
        }
        return paramStruct
    }
}
