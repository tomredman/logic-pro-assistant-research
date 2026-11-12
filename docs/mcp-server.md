# The MCP server in Logic Pro 13

## What is in the app

- The Equinox framework contains a Model Context Protocol server: an HTTP server on localhost, session handling, a tool list, and a tool search for a larger catalog.
- The EquinoxUI framework contains the text for a setting with the title "Allow external assistants to connect to Logic Pro", a privacy dialog, a connection approval dialog, and a list of connections.
- The text says: each new client needs approval with Touch ID or the password, only clients on the same Mac can connect, the feature needs Apple Creator Studio, and the server has no OAuth.

## What we could not find

Tested on build 7801, macOS 26.6 and 27.2.

| Check | Result |
|---|---|
| All Settings panes and tabs, the app menu, the assistant menu | No MCP control |
| Code that shows the setting | Not found. EquinoxUI has the text only. |
| Code that starts the server | Three binaries link to Equinox. None imports the MCP server classes. |
| System feature flag | The frameworks do not call the feature flag functions. No related flag file is on the system. |
| Open ports | One TCP port. It is Logic Remote, not MCP. |

## Conclusion

The server code and the text ship in the app, but the part that shows the setting and starts the server is not in this build. There is no local switch. A later release will probably turn it on. One other possibility is a switch on Apple's servers, because the app contains a remote configuration framework. We could not confirm that.

When it is active, it will probably give external agents the same functions as the internal API.
