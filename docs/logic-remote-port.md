# The open network port

Logic Pro listens on one TCP port on all network interfaces. The port number changes at each start (for example 50959, then 51245).

It is the Logic Remote service, not an MCP server:

- It gives no HTTP response.
- When a client connects, it immediately sends a short binary message that contains the name of the Mac.
- The Mac advertises a Bonjour service of type `_apple-lgremote`.
- The port was open before the assistant was available on the test Mac.

Logic Remote is a full remote control protocol, but it is private and binary, with a pairing step. We did not decode it.
