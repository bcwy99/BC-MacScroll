//
//  MouseAcceleration.swift
//  BC MacScroll
//
//  Turns pointer acceleration off (and back on) through the HID event system.
//  Based on https://github.com/apsun/NoMouseAccel
//

import Foundation
import IOKit
import CHIDSupport

enum MouseAcceleration {

    private static let property = kIOHIDMouseAccelerationType as NSString as CFString
    private static let savedKey = "OriginalAccel"
    private static let macOSDefault: Int32 = 45056

    /// `disable == true` sets acceleration to -1 (off).
    /// `disable == false` restores the user's previous value, but only if we turned it off.
    static func apply(disable: Bool) {
        let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)

        // Can be nil right after wake while the HID system is still starting.
        var current: Int32 = 0
        var haveCurrent = false
        if let value = IOHIDEventSystemClientCopyProperty(client, property),
           CFGetTypeID(value) == CFNumberGetTypeID() {
            haveCurrent = CFNumberGetValue((value as! CFNumber), .sInt32Type, &current)
        }

        if haveCurrent && current != -1 {
            UserDefaults.standard.set(current, forKey: savedKey)
        }

        var target: Int32
        if disable {
            guard !(haveCurrent && current == -1) else { return }
            target = -1
        } else {
            guard haveCurrent && current == -1 else { return }
            let saved = UserDefaults.standard.object(forKey: savedKey) as? Int
            target = Int32(saved ?? Int(macOSDefault))
        }

        guard let number = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &target) else { return }
        IOHIDEventSystemClientSetProperty(client, property, number)
    }
}
