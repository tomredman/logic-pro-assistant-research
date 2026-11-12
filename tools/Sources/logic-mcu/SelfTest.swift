import Foundation

/// Protocol tests that do not use MIDI ports or Logic Pro.
func runSelfTest() -> Int32 {
    var failures = 0
    func check(_ name: String, _ ok: Bool) {
        print((ok ? "ok    " : "FAIL  ") + name)
        if !ok { failures += 1 }
    }

    var parser = MIDIStreamParser()
    var state = SurfaceState()

    // LCD text divided between two packets.
    var msgs = parser.feed([0xF0, 0x00, 0x00, 0x66, 0x14, 0x12, 0x00, 0x56, 0x6F])
    check("incomplete SysEx gives no message", msgs.isEmpty)
    msgs = parser.feed([0x63, 0x61, 0x6C, 0x73, 0xF7])
    check("SysEx completes", msgs.count == 1)
    msgs.forEach { _ = state.apply($0) }
    check("LCD row 1 starts with Vocals", state.lcdRow(0).hasPrefix("Vocals"))
    check("LCD cell 1 is Vocals", state.lcdCells(0)[0] == "Vocals")

    // LCD text on row 2, cell 3.
    msgs = parser.feed([0xF0, 0x00, 0x00, 0x66, 0x14, 0x12, 56 + 14] + Array("-12.5dB".utf8) + [0xF7])
    msgs.forEach { _ = state.apply($0) }
    check("LCD row 2 cell 3", state.lcdCells(1)[2] == "-12.5dB")

    // Running status: two note-on messages with one status byte.
    msgs = parser.feed([0x90, 0x2B, 0x7F, 0x2C, 0x00])
    check("running status gives two messages", msgs.count == 2)
    msgs.forEach { _ = state.apply($0) }
    check("plugin LED is on", state.ledsOn.contains("plugin"))
    check("eq LED is off", !state.ledsOn.contains("eq"))

    // Fader position.
    msgs = parser.feed([0xE2, 0x7F, 0x7F])
    msgs.forEach { _ = state.apply($0) }
    check("fader 3 is at maximum", state.faders[2] == 16383)

    // Assignment display: "PL".
    msgs = parser.feed([0xB0, 0x4B, 0x10, 0xB0, 0x4A, 0x0C])
    msgs.forEach { _ = state.apply($0) }
    check("assignment display shows PL", state.assignment == "PL")

    // Real-time bytes in the middle of a message.
    msgs = parser.feed([0xB0, 0xF8, 0x30, 0x06])
    check("real-time byte is ignored", msgs == [.controlChange(channel: 0, number: 0x30, value: 6)])

    print(failures == 0 ? "All tests passed." : "\(failures) test(s) failed.")
    return failures == 0 ? 0 : 1
}
