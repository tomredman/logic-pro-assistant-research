# Logic Pro assistant research

Notes and tools from an examination of Logic Pro 13 (Creator Studio edition, build 7801, November 2026) on macOS 26.6 and 27.2. The subject is how the Intelligent Assistant operates Logic Pro, and how an external program can operate Logic Pro.

This is independent research. It has no connection with Apple. The repository contains no Apple files: no system prompt, no type declarations, and no debug archives. The documents describe the results in our words. The interfaces described here are private. Apple can change them in each release.

## Main results

1. **The assistant writes programs.** For each request, a language model writes a short JavaScript program. Logic Pro runs the program against 20 internal objects (tracks, regions, transport, plug-ins, and others) and gives the result back to the model. See [docs/assistant-architecture.md](docs/assistant-architecture.md).
2. **The internal API is large but has gaps.** It has about 350 functions. It can insert plug-ins and set parameters by name. It has no sends, bus routing, sidechain source, automation, or audio analysis. See [docs/internal-api-index.md](docs/internal-api-index.md).
3. **A debug log is available.** One user default turns on a debug archive that contains the prompt, each program, and each result. See [docs/debug-archive.md](docs/debug-archive.md).
4. **An MCP server is in the app, but it is not active.** The code and the setting text are there. No code shows the setting or starts the server in this build. See [docs/mcp-server.md](docs/mcp-server.md).
5. **The Accessibility API is a good control path.** The channel strip and the stock plug-in windows give named controls with readouts in real units. One script inserts a Channel EQ, sets a band to exact values, reads the values back, and toggles bypass in 3 seconds. See [docs/accessibility-control.md](docs/accessibility-control.md).
6. **The open network port is Logic Remote.** See [docs/logic-remote-port.md](docs/logic-remote-port.md).

## Tools

The [tools](tools) folder is a Swift package with two command-line tools:

- `logic-ax`: examine and operate Logic Pro interface elements through the Accessibility API.
- `logic-mcu`: a virtual Mackie Control device, with a command interface.

See [tools/README.md](tools/README.md).

## Limits of this research

- One Mac, one Logic Pro build, English only.
- The assistant was in beta.
- Statements about what the assistant cannot do come from its prompt and API list. They are not from a full test of each function.
