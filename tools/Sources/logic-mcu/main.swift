import Foundation

let usage = """
logic-mcu: a virtual Mackie Control device for Logic Pro

Usage:
  logic-mcu serve [--verbose] [--name <port name>]   Create the MIDI ports and wait for commands
  logic-mcu send <command> [; <command> ...]         Send commands to the server
  logic-mcu selftest                                 Run the protocol tests (no MIDI, no Logic Pro)

\(helpText)
"""

signal(SIGPIPE, SIG_IGN)
setvbuf(stdout, nil, _IOLBF, 0)

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "selftest":
    exit(runSelfTest())

case "send":
    let line = args.dropFirst().joined(separator: " ")
    guard !line.isEmpty else { print(usage); exit(2) }
    exit(sendCommand(path: defaultSocketPath, line: line))

case "serve":
    var name = "Logic MCU"
    if let i = args.firstIndex(of: "--name"), i + 1 < args.count { name = args[i + 1] }
    do {
        let surface = try Surface(name: name)
        surface.verbose = args.contains("--verbose")
        let server = ControlServer(path: defaultSocketPath) { runCommands($0, on: surface) }
        try server.start()
        print("MIDI ports \"\(name)\" are open. Command socket: \(defaultSocketPath)")
        print("Type commands here, or use `logic-mcu send <command>` from a second terminal.")
        Thread.detachNewThread {
            while let line = readLine() {
                if line == "quit" || line == "exit" { exit(0) }
                let reply = runCommands(line, on: surface)
                if !reply.isEmpty { print(reply) }
            }
        }
        RunLoop.main.run()
    } catch {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        exit(1)
    }

default:
    print(usage)
    exit(args.isEmpty ? 2 : 0)
}
