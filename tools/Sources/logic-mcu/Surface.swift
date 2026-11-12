import CoreMIDI
import Foundation

struct SurfaceError: Error, CustomStringConvertible {
    let description: String
}

/// A virtual Mackie Control device. Logic Pro connects to its two virtual MIDI ports.
final class Surface {
    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private var dest = MIDIEndpointRef()
    private let lock = NSLock()
    private var parser = MIDIStreamParser()
    private var state = SurfaceState()
    private var lastChange = Date.distantPast
    private var received = 0
    var verbose = false

    init(name: String) throws {
        var st = MIDIClientCreateWithBlock(name as CFString, &client, nil)
        guard st == noErr else { throw SurfaceError(description: "MIDIClientCreate failed: \(st)") }
        st = MIDISourceCreate(client, name as CFString, &source)
        guard st == noErr else { throw SurfaceError(description: "MIDISourceCreate failed: \(st)") }
        st = MIDIDestinationCreateWithBlock(client, name as CFString, &dest) { [unowned self] list, _ in
            self.receive(list)
        }
        guard st == noErr else { throw SurfaceError(description: "MIDIDestinationCreate failed: \(st)") }
        // Fixed IDs. Logic Pro then finds the same ports after each restart of this tool.
        MIDIObjectSetIntegerProperty(source, kMIDIPropertyUniqueID, 0x5052_4F31)
        MIDIObjectSetIntegerProperty(dest, kMIDIPropertyUniqueID, 0x5052_4F32)
    }

    // MARK: Receive

    private func receive(_ list: UnsafePointer<MIDIPacketList>) {
        var bytes: [UInt8] = []
        let count = Int(list.pointee.numPackets)
        // MIDIPacketList is a packed structure: numPackets (4 bytes), then the first packet.
        var packet = UnsafeRawPointer(list).advanced(by: 4).assumingMemoryBound(to: MIDIPacket.self)
        for _ in 0..<count {
            let len = Int(packet.pointee.length)
            // MIDIPacket is a packed structure: timeStamp (8 bytes), length (2 bytes), then data.
            let data = UnsafeRawBufferPointer(start: UnsafeRawPointer(packet).advanced(by: 10), count: len)
            bytes.append(contentsOf: data)
            packet = UnsafePointer(MIDIPacketNext(packet))
        }
        lock.lock()
        let messages = parser.feed(bytes)
        var replies: [[UInt8]] = []
        for m in messages {
            received += 1
            if state.apply(m) { lastChange = Date() }
            if case .sysex(let p) = m, let r = handshakeReply(p) { replies.append(r) }
            if verbose { log(m) }
        }
        lock.unlock()
        for r in replies { send(r) }
    }

    /// Replies for the device query and version request. This part is not yet tested with Logic Pro.
    private func handshakeReply(_ p: [UInt8]) -> [UInt8]? {
        guard p.count >= 5, Array(p[0..<3]) == MCU.sysexHeader else { return nil }
        let device = p[3]
        let serial: [UInt8] = Array("LOGICMC".utf8)
        switch p[4] {
        case 0x00:  // device query -> host connection query (serial number and challenge)
            return [0xF0] + MCU.sysexHeader + [device, 0x01] + serial + [0x01, 0x02, 0x03, 0x04, 0xF7]
        case 0x02:  // host connection reply -> host connection confirmation
            return [0xF0] + MCU.sysexHeader + [device, 0x03] + serial + [0xF7]
        case 0x13:  // firmware version request
            return [0xF0] + MCU.sysexHeader + [device, 0x14] + Array("V3.00".utf8) + [0xF7]
        default:
            return nil
        }
    }

    private func log(_ m: MIDIMessage) {
        var line: String
        switch m {
        case .sysex(let p) where p.count >= 6 && p[4] == 0x12:
            let text = String(p[6...].map { ($0 >= 0x20 && $0 < 0x7F) ? Character(UnicodeScalar($0)) : "?" })
            line = "lcd@\(p[5]) \"\(text)\""
        case .sysex(let p):
            line = "sysex " + p.map { String(format: "%02X", $0) }.joined(separator: " ")
        case .noteOn(_, let n, let v):
            line = "led \(MCU.buttonName(n)) \(v)"
        case .pitchBend(let ch, let v):
            line = "fader \(ch + 1) \(String(format: "%.3f", Double(v) / 16383.0))"
        case .controlChange(_, let n, let v):
            line = String(format: "cc 0x%02X %d", n, v)
        case .channelPressure:
            return  // level meters, too many messages
        default:
            line = "\(m)"
        }
        FileHandle.standardError.write(Data(("< " + line + "\n").utf8))
    }

    // MARK: Send

    func send(_ bytes: [UInt8]) {
        let size = 64 + bytes.count
        let buf = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 4)
        defer { buf.deallocate() }
        let list = buf.assumingMemoryBound(to: MIDIPacketList.self)
        var packet = MIDIPacketListInit(list)
        packet = MIDIPacketListAdd(list, size, packet, 0, bytes.count, bytes)
        MIDIReceived(source, list)
    }

    func press(note: UInt8, holdMs: Int = 40) {
        send([0x90, note, 0x7F])
        Thread.sleep(forTimeInterval: Double(holdMs) / 1000.0)
        send([0x90, note, 0x00])
    }

    /// Turn one V-Pot. A positive delta is clockwise. One message moves a maximum of 15 steps.
    func vpot(strip: Int, delta: Int) {
        var remaining = abs(delta)
        while remaining > 0 {
            let step = min(remaining, 15)
            let value = UInt8(step) | (delta < 0 ? 0x40 : 0x00)
            send([0xB0, MCU.vpotRotateBase + UInt8(strip), value])
            remaining -= step
            Thread.sleep(forTimeInterval: 0.005)
        }
    }

    /// Move one fader. `value` is 0.0...1.0. Strip 8 is the master fader.
    func fader(strip: Int, value: Double) {
        let v = Int((max(0, min(1, value)) * 16383).rounded())
        let touch = MCU.faderTouchBase + UInt8(strip)
        send([0x90, touch, 0x7F])
        send([0xE0 | UInt8(strip), UInt8(v & 0x7F), UInt8(v >> 7)])
        Thread.sleep(forTimeInterval: 0.03)
        send([0x90, touch, 0x00])
    }

    // MARK: State

    func snapshot() -> SurfaceState {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    func receivedCount() -> Int {
        lock.lock(); defer { lock.unlock() }
        return received
    }

    /// Wait until the host sends no state change for `quietMs`. Stop after `maxMs`.
    func settle(quietMs: Int, maxMs: Int) {
        let end = Date().addingTimeInterval(Double(maxMs) / 1000.0)
        while Date() < end {
            lock.lock()
            let quiet = Date().timeIntervalSince(lastChange) * 1000.0
            lock.unlock()
            if quiet >= Double(quietMs) { return }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
}
