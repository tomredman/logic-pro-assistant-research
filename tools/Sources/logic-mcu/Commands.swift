import Foundation

let helpText = """
Commands (put `;` between commands to run a sequence):
  lcd                      Show the two LCD rows and the assignment display
  cells                    Show the LCD as 8 cells for each row
  state                    Show the full surface state as JSON
  press <button> [ms]      Press and release a button (name or 0xNN note number)
  buttons                  List the button names
  select|mute|solo|rec <1-8>   Press a strip button
  vpush <1-8>              Push a V-Pot
  vpot <1-8> <delta>       Turn a V-Pot (positive is clockwise)
  fader <1-9> <0.0-1.0>    Move a fader (9 is the master fader)
  wait <ms>                Wait
  settle [quietMs] [maxMs] Wait until Logic Pro stops sending changes (default 150, 2000)
  raw <hex bytes>          Send raw MIDI bytes, for example: raw 90 2B 7F
  count                    Show the number of messages received from Logic Pro
  help
"""

func runCommands(_ line: String, on surface: Surface) -> String {
    line.split(separator: ";")
        .map { runCommand(String($0).trimmingCharacters(in: .whitespaces), on: surface) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
}

private func stripIndex(_ s: String?, max: Int = 8) -> Int? {
    guard let s, let n = Int(s), n >= 1, n <= max else { return nil }
    return n - 1
}

func runCommand(_ line: String, on surface: Surface) -> String {
    let parts = line.split(separator: " ").map(String.init)
    guard let cmd = parts.first?.lowercased() else { return "" }
    let arg1 = parts.count > 1 ? parts[1] : nil
    let arg2 = parts.count > 2 ? parts[2] : nil

    switch cmd {
    case "help":
        return helpText
    case "lcd":
        let s = surface.snapshot()
        return "[\(s.assignment)] |\(s.lcdRow(0))|\n     |\(s.lcdRow(1))|"
    case "cells":
        let s = surface.snapshot()
        return (0..<2).map { r in s.lcdCells(r).map { $0.padding(toLength: 7, withPad: " ", startingAt: 0) }.joined(separator: "|") }
            .joined(separator: "\n")
    case "state":
        return surface.snapshot().json()
    case "count":
        return "\(surface.receivedCount())"
    case "buttons":
        return MCU.buttons.sorted { $0.value < $1.value }.map { String(format: "0x%02X %@", $0.value, $0.key) }.joined(separator: "\n")
    case "press":
        guard let name = arg1?.lowercased() else { return "error: press <button>" }
        let note: UInt8?
        if name.hasPrefix("0x") { note = UInt8(name.dropFirst(2), radix: 16) } else { note = MCU.buttons[name] }
        guard let note else { return "error: unknown button \(name)" }
        surface.press(note: note, holdMs: Int(arg2 ?? "") ?? 40)
        return ""
    case "select", "mute", "solo", "rec", "vpush":
        guard let i = stripIndex(arg1) else { return "error: \(cmd) <1-8>" }
        let base: UInt8
        switch cmd {
        case "select": base = MCU.selectBase
        case "mute": base = MCU.muteBase
        case "solo": base = MCU.soloBase
        case "rec": base = MCU.recBase
        default: base = MCU.vpotPushBase
        }
        surface.press(note: base + UInt8(i))
        return ""
    case "vpot":
        guard let i = stripIndex(arg1), let d = Int(arg2 ?? "") else { return "error: vpot <1-8> <delta>" }
        surface.vpot(strip: i, delta: d)
        return ""
    case "fader":
        guard let i = stripIndex(arg1, max: 9), let v = Double(arg2 ?? "") else { return "error: fader <1-9> <0.0-1.0>" }
        surface.fader(strip: i, value: v)
        return ""
    case "wait":
        Thread.sleep(forTimeInterval: Double(Int(arg1 ?? "") ?? 100) / 1000.0)
        return ""
    case "settle":
        Thread.sleep(forTimeInterval: 0.05)
        surface.settle(quietMs: Int(arg1 ?? "") ?? 150, maxMs: Int(arg2 ?? "") ?? 2000)
        return ""
    case "raw":
        let bytes = parts.dropFirst().compactMap { UInt8($0, radix: 16) }
        guard !bytes.isEmpty, bytes.count == parts.count - 1 else { return "error: raw <hex bytes>" }
        surface.send(bytes)
        return ""
    default:
        return "error: unknown command \(cmd). Use help."
    }
}
