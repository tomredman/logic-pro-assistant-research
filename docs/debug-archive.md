# How to get an assistant debug archive

Tested on Logic Pro Creator Studio 13.0 (build 7801), macOS 27.2.

## Procedure

1. Quit Logic Pro.
2. In Terminal:
   ```
   defaults write com.apple.mobilelogic MAFlowLoggingEnabled -bool true
   ```
   macOS can ask for permission to access data from other apps. Allow it.
3. Open Logic Pro and a project.
4. Give the assistant one or more requests.
5. Send `/save` in the assistant message field.
6. The reply gives the path of the archive. It is in:
   ```
   ~/Library/Containers/com.apple.mobilelogic/Data/tmp/MAFlowTranscripts/
   ```
7. Copy the archive with Terminal. macOS protects the Logic Pro container from other apps.

To undo: `defaults delete com.apple.mobilelogic MAFlowLoggingEnabled`

## Archive layout

The archive is a folder with the extension `.equinoxarchive`.

| File | Contents |
|---|---|
| `instructions.txt` | The full system prompt, with the API type declarations |
| `config.json` | Backend, model, number of skills, context window settings |
| `manifest.json` | Times, locale, operating system and app version |
| `metrics.json` | Token counts and cache rate |
| `TIMELINE.txt` | The turns and rounds in sequence |
| `transcript.json`, `events.jsonl` | The conversation and all events |
| `turns/turn-N/input.json` | The user message |
| `turns/turn-N/rounds/round-N/prompt.txt` | The prompt addition for that round (project state) |
| `turns/turn-N/rounds/round-N/raw.txt` | The model output |
| `turns/turn-N/rounds/round-N/code.js` | The program |
| `turns/turn-N/rounds/round-N/result.json` | Each call with its arguments, and the return value |
| `turns/turn-N/rounds/round-N/usage.json` | Tokens and latency |

The archive contains your messages and project data (track names, tempo, regions). Examine it before you share it.

## Live log

The unified log shows each program while the assistant runs:

```
log stream --level debug --style compact --predicate '(process == "Logic Pro Creator Studio" OR process == "com.apple.musicapps.MAFlowService") AND (senderImagePath CONTAINS[c] "MAFlow" OR senderImagePath CONTAINS[c] "Equinox" OR subsystem CONTAINS[c] "MAFlow" OR subsystem CONTAINS[c] "equinox")'
```

The Bridge lines contain the program text and the result. macOS replaces some values with `<private>`.
