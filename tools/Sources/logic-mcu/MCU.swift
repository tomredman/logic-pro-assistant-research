import Foundation

/// Mackie Control (MCU) protocol constants and decode functions.
/// This file has no CoreMIDI dependency.
enum MCU {
    /// Button name to MIDI note number. A press is note-on velocity 127, a release is velocity 0.
    static let buttons: [String: UInt8] = [
        // Assignment section
        "track": 0x28, "send": 0x29, "pan": 0x2A, "plugin": 0x2B, "eq": 0x2C, "instrument": 0x2D,
        // Bank and channel
        "bank-left": 0x2E, "bank-right": 0x2F, "channel-left": 0x30, "channel-right": 0x31,
        "flip": 0x32, "global": 0x33, "name-value": 0x34, "smpte-beats": 0x35,
        // Function keys
        "f1": 0x36, "f2": 0x37, "f3": 0x38, "f4": 0x39, "f5": 0x3A, "f6": 0x3B, "f7": 0x3C, "f8": 0x3D,
        // Global view
        "midi-tracks": 0x3E, "inputs": 0x3F, "audio-tracks": 0x40, "audio-instruments": 0x41,
        "aux": 0x42, "busses": 0x43, "outputs": 0x44, "user": 0x45,
        // Modifiers
        "shift": 0x46, "option": 0x47, "control": 0x48, "cmd": 0x49,
        // Automation
        "read": 0x4A, "write": 0x4B, "trim": 0x4C, "touch": 0x4D, "latch": 0x4E, "group": 0x4F,
        // Utilities
        "save": 0x50, "undo": 0x51, "cancel": 0x52, "enter": 0x53,
        // Transport
        "marker": 0x54, "nudge": 0x55, "cycle": 0x56, "drop": 0x57, "replace": 0x58, "click": 0x59,
        "solo": 0x5A, "rewind": 0x5B, "forward": 0x5C, "stop": 0x5D, "play": 0x5E, "record": 0x5F,
        // Cursor
        "up": 0x60, "down": 0x61, "left": 0x62, "right": 0x63, "zoom": 0x64, "scrub": 0x65,
    ]

    // Per-strip note bases. Add the strip index 0...7.
    static let recBase: UInt8 = 0x00
    static let soloBase: UInt8 = 0x08
    static let muteBase: UInt8 = 0x10
    static let selectBase: UInt8 = 0x18
    static let vpotPushBase: UInt8 = 0x20
    static let faderTouchBase: UInt8 = 0x68

    // Control change numbers.
    static let vpotRotateBase: UInt8 = 0x10   // surface to host
    static let vpotRingBase: UInt8 = 0x30     // host to surface
    static let digitBase: UInt8 = 0x40        // host to surface, 0x40...0x4B

    static let sysexHeader: [UInt8] = [0x00, 0x00, 0x66]

    static func buttonName(_ note: UInt8) -> String {
        if let n = buttons.first(where: { $0.value == note })?.key { return n }
        switch note {
        case 0x00...0x07: return "rec\(note + 1)"
        case 0x08...0x0F: return "solo\(note - 0x08 + 1)"
        case 0x10...0x17: return "mute\(note - 0x10 + 1)"
        case 0x18...0x1F: return "select\(note - 0x18 + 1)"
        case 0x20...0x27: return "vpush\(note - 0x20 + 1)"
        default: return String(format: "0x%02X", note)
        }
    }

    /// Decode one 7-segment display value to a character.
    static func digitChar(_ value: UInt8) -> Character {
        let v = value & 0x3F
        let ascii = v < 0x20 ? v + 0x40 : v
        return Character(UnicodeScalar(ascii))
    }
}

enum MIDIMessage: Equatable {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    case controlChange(channel: UInt8, number: UInt8, value: UInt8)
    case pitchBend(channel: UInt8, value: Int)
    case channelPressure(channel: UInt8, value: UInt8)
    case sysex([UInt8])            // payload without F0 and F7
    case other([UInt8])
}

/// Byte stream parser. It accepts running status and SysEx that is divided between packets.
struct MIDIStreamParser {
    private var sysex: [UInt8]? = nil
    private var status: UInt8 = 0
    private var data: [UInt8] = []

    mutating func feed(_ bytes: [UInt8]) -> [MIDIMessage] {
        var out: [MIDIMessage] = []
        for b in bytes {
            if b >= 0xF8 { continue }                      // real-time
            if b == 0xF0 { sysex = []; status = 0; continue }
            if b == 0xF7 {
                if let s = sysex { out.append(.sysex(s)) }
                sysex = nil
                continue
            }
            if sysex != nil {
                if b < 0x80 { sysex!.append(b); continue }
                sysex = nil                                // aborted SysEx
            }
            if b >= 0x80 {
                status = b
                data = []
                if Self.dataLength(b) == 0 { status = 0 }
                continue
            }
            guard status != 0 else { continue }
            data.append(b)
            if data.count == Self.dataLength(status) {
                out.append(Self.make(status, data))
                data = []
                if status >= 0xF0 { status = 0 }
            }
        }
        return out
    }

    static func dataLength(_ status: UInt8) -> Int {
        switch status & 0xF0 {
        case 0xC0, 0xD0: return 1
        case 0xF0:
            switch status {
            case 0xF1, 0xF3: return 1
            case 0xF2: return 2
            default: return 0
            }
        default: return 2
        }
    }

    static func make(_ status: UInt8, _ d: [UInt8]) -> MIDIMessage {
        let ch = status & 0x0F
        switch status & 0xF0 {
        case 0x80: return .noteOff(channel: ch, note: d[0], velocity: d[1])
        case 0x90: return .noteOn(channel: ch, note: d[0], velocity: d[1])
        case 0xB0: return .controlChange(channel: ch, number: d[0], value: d[1])
        case 0xD0: return .channelPressure(channel: ch, value: d[0])
        case 0xE0: return .pitchBend(channel: ch, value: Int(d[0]) | (Int(d[1]) << 7))
        default: return .other([status] + d)
        }
    }
}

/// The surface state that the host (Logic Pro) sends to the device.
struct SurfaceState {
    var lcd = [UInt8](repeating: 0x20, count: 112)          // 2 rows of 56 characters
    var faders = [Int](repeating: 0, count: 9)              // 14-bit, strip 1...8 and master
    var vpotRings = [UInt8](repeating: 0, count: 8)
    var leds: [UInt8: UInt8] = [:]                          // note to velocity (0 off, 127 on, 1 blink)
    var digits = [UInt8](repeating: 0x20, count: 12)        // CC 0x40...0x4B

    /// Apply one host message. The return value is true if the message changed the state.
    mutating func apply(_ m: MIDIMessage) -> Bool {
        switch m {
        case .sysex(let p):
            // 00 00 66 <device> 12 <offset> <characters...>
            guard p.count >= 6, Array(p[0..<3]) == MCU.sysexHeader, p[4] == 0x12 else { return false }
            var pos = Int(p[5])
            for c in p[6...] where pos < lcd.count {
                lcd[pos] = c
                pos += 1
            }
            return true
        case .pitchBend(let ch, let v):
            guard ch < 9 else { return false }
            faders[Int(ch)] = v
            return true
        case .controlChange(_, let n, let v):
            if n >= MCU.vpotRingBase, n < MCU.vpotRingBase + 8 {
                vpotRings[Int(n - MCU.vpotRingBase)] = v
                return true
            }
            if n >= MCU.digitBase, n < MCU.digitBase + 12 {
                digits[Int(n - MCU.digitBase)] = v
                return true
            }
            return false
        case .noteOn(_, let note, let vel):
            leds[note] = vel
            return true
        case .noteOff(_, let note, _):
            leds[note] = 0
            return true
        default:
            return false
        }
    }

    func lcdRow(_ row: Int) -> String {
        let slice = lcd[(row * 56)..<(row * 56 + 56)]
        return String(slice.map { ($0 >= 0x20 && $0 < 0x7F) ? Character(UnicodeScalar($0)) : "?" })
    }

    /// The 8 cells of one LCD row. Each cell has 7 characters and is above one strip.
    func lcdCells(_ row: Int) -> [String] {
        let chars = Array(lcdRow(row))
        return (0..<8).map { String(chars[($0 * 7)..<($0 * 7 + 7)]).trimmingCharacters(in: .whitespaces) }
    }

    /// The 2-character assignment display.
    var assignment: String {
        String([MCU.digitChar(digits[11]), MCU.digitChar(digits[10])])
    }

    /// The 10-character position display.
    var position: String {
        String((0..<10).reversed().map { MCU.digitChar(digits[$0]) })
    }

    var ledsOn: [String] {
        leds.filter { $0.value != 0 }.keys.sorted().map { MCU.buttonName($0) }
    }

    func json() -> String {
        let obj: [String: Any] = [
            "lcd": [lcdRow(0), lcdRow(1)],
            "cells": [lcdCells(0), lcdCells(1)],
            "assignment": assignment,
            "position": position,
            "faders": faders.map { Double($0) / 16383.0 },
            "vpotRings": vpotRings.map { Int($0) },
            "ledsOn": ledsOn,
        ]
        let data = try! JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}
