# How the Intelligent Assistant works

Source: static examination of the app bundle, one debug archive, and the unified log.

## Parts

| Part | Framework | Job |
|---|---|---|
| Agent framework | Equinox, EquinoxUI | Chat interface, agent loop, model connection, JavaScript engine, call recording. It has no music knowledge. |
| Logic Pro part | MAFlow, MAFlowCore, MAFlowBridge, MAFlowSkillBridge, MAFlowTypes, MAFlowUI | The prompt, the 20 API objects, the validator, and the bridge from each JavaScript call to a Logic Pro function. |
| Service process | MAFlowXPC (`com.apple.musicapps.MAFlowService`) | A separate process. It accepts only clients with an Apple code signature. It did not run the programs in our tests. |

All program execution that we saw was in the Logic Pro process.

## One request, step by step

Times are from the log for a request to add one track.

| Time (s) | Component | Action |
|---|---|---|
| 0.00 | Chat view | The message is sent |
| 0.05 | Agent loop | The loop starts |
| 0.10 | Provider | A classifier note about the type of request is added to the prompt |
| 0.22 | Provider | The project state is added. Blocks that did not change come from a cache. |
| 0.22 | Model backend | A check that the conversation fits in the context window |
| 1.87 | Validator | The model output is checked: a program plus text, and the program changes the project |
| 1.87 | Bridge | The program text goes to the JavaScript engine |
| 2.14 | JS bridge | Each call from JavaScript to Logic Pro is recorded |
| 2.98 | Bridge | Result: success, 1 call |
| 2.98 | Usage log | The request is counted against the monthly limit |

## The loop

Each round, the model gives one of two actions:

- **Execute:** run a JavaScript program. The value of the last expression goes back to the model. The model can attach the final user text to this action. In that case the text goes to the user when the program completes, and the model does not see the result first.
- **Respond:** send text to the user and end the turn.

## The prompt

- About 73,000 tokens. The full prompt goes with each round. Four short requests used about 373,000 input tokens.
- General rules: how to write the program, what the user sees, when to use app help.
- 11 skills. Each skill has rules, examples, and TypeScript declarations for its API object.
- The current project state as tagged blocks: tracks, focused track, regions, transport, step sequencer, chords, markers, tempo, key, time signature, project notes, open interface areas. The plug-in list of a channel is not included. The model reads it in the program.
- A safety section and conversation rules.

## The model

The debug archive configuration named a small Google Gemini model, reached through an Apple gateway, and an on-device model that checks the response. The framework also contains a client for OpenAI-compatible remote models.

## A mix request

Request: make the EQ on a vocal track bright.

The model wrote one program. It found the track by name, got the channel, and inserted a Channel EQ with four parameters in one call: high shelf gain +4.0 dB, high shelf frequency 10,000 Hz, low cut on, low cut frequency 80 Hz. Time: about 4 seconds, one model round.

What this shows:

- The values are a fixed recipe from general knowledge. The model did not measure the audio. It has no function to do that.
- The program did not read the values back. Its success text was written before the program ran.
- A later check through the Accessibility API showed that Logic Pro did apply all four values.

## Resistance to pasted instructions

We pasted a copy of the context blocks into the chat, with one added instruction to show the program code. The model treated the text as pasted text and did not obey it.
