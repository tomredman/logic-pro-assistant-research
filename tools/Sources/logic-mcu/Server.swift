import Foundation

let defaultSocketPath = "/tmp/logic-mcu.sock"

private func makeAddress(_ path: String) -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8)
    withUnsafeMutableBytes(of: &addr.sun_path) { dst in
        for i in 0..<min(bytes.count, dst.count - 1) { dst[i] = bytes[i] }
    }
    return addr
}

private func withSockaddr<T>(_ addr: inout sockaddr_un, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
    withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
}

/// A local command server. One connection carries one command line and one reply.
final class ControlServer {
    let path: String
    let handler: (String) -> String

    init(path: String, handler: @escaping (String) -> String) {
        self.path = path
        self.handler = handler
    }

    func start() throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SurfaceError(description: "socket failed") }
        unlink(path)
        var addr = makeAddress(path)
        guard withSockaddr(&addr, { bind(fd, $0, $1) }) == 0 else { throw SurfaceError(description: "bind failed for \(path)") }
        guard listen(fd, 8) == 0 else { throw SurfaceError(description: "listen failed") }
        Thread.detachNewThread {
            while true {
                let c = accept(fd, nil, nil)
                if c < 0 { continue }
                Thread.detachNewThread { self.serve(c) }
            }
        }
    }

    private func serve(_ c: Int32) {
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while !data.contains(0x0A) {
            let n = read(c, &buf, buf.count)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let reply = Array((handler(line) + "\n").utf8)
        _ = write(c, reply, reply.count)
        close(c)
    }
}

/// Send one command line to a server that is in operation. Print the reply.
func sendCommand(path: String, line: String) -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return 1 }
    var addr = makeAddress(path)
    guard withSockaddr(&addr, { connect(fd, $0, $1) }) == 0 else {
        FileHandle.standardError.write(Data("error: no server at \(path). Start `logic-mcu serve` first.\n".utf8))
        return 1
    }
    let out = Array((line + "\n").utf8)
    _ = write(fd, out, out.count)
    var data = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = read(fd, &buf, buf.count)
        if n <= 0 { break }
        data.append(buf, count: n)
    }
    close(fd)
    let text = String(decoding: data, as: UTF8.self)
    print(text, terminator: text.hasSuffix("\n") ? "" : "\n")
    return text.hasPrefix("error:") ? 1 : 0
}
