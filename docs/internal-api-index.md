# Internal assistant API: function index

Source: the type declarations in the assistant prompt, from a debug archive. This index gives the names only. It is a private interface, it runs only inside Logic Pro, and only the Apple assistant can call it.

20 objects, about 350 functions.

## Most important for mixing

**`_channels`** (plug-ins)

- Read: `getChannels` `count` `getChannelId` `getChannelIds` `getMasterChannelId` `getPlugins` `getAudioPlugins` `getInstrumentPlugins` `getMidiPlugins` `getPlugin` `getParameters` `getParameter` `getSettings`
- Insert: `addPlugin` `addAudioPlugin` `addInstrumentPlugin` `addMidiPlugin` `addMasteringAssistant`
- Change: `setParameter` `setParameters` `loadSetting` `replacePlugin`
- Bypass: `bypassPlugin` `unbypassPlugin` `toggleBypass`
- Remove: `removePlugin` `removeAudioPlugin` `removeInstrumentPlugin` `removeMidiPlugin`
- Window: `openPlugin` `closePlugin`
- Timing: `wait`

Data shapes:

- Channel: name, muted, soloed, volume (dB text), pan, masteringAssistantAvailable
- PlugIn: slot number, name, bypassed, supportsSidechain, parameters, currentSetting
- PlugInParameter: parameterID, name, value (text), description (range and type)
- PlugInConfig (for insert): setting, character, parameters

**`_tracks`** (mixer strip controls and track structure)

- Read: `getTracks` `get` `getTracksByType` `getSelectedTracks` `getFocusedTrack` `count` `getTrackId` `getTrackIds`
- Level: `setVolume` `adjustVolume` `setPan` `adjustPan` `rampTo` (timed change of volume or pan, not automation)
- State: `mute` `unmute` `toggleMute` `solo` `toggleSolo` `clearSolos` `select` `clearSelections` `hide` `show`
- Structure: `add` `insert` `delete` `deleteAll` `duplicate` `move` `update` `createFolderStack` `createSummingStack` `convertToSummingStack` `flattenStack`
- Record: `recordEnable` `recordDisable` `toggleRecordEnabled` `enableInputMonitoring` `disableInputMonitoring` `toggleInputMonitoring`
- Other: `setColor` `resetAllTracks` `wait`

**`_transport`**: `isPlaying` `isPaused` `isRecording` `canCaptureRecord` `getPosition` `getCycle` `isCycleActive` `getState` `play` `playFromPosition` `pause` `stop` `togglePlayback` `startRecording` `stopRecording` `toggleRecording` `captureRecording` `setPosition` `movePosition` `goToBeginning` `enableCycle` `disableCycle` `toggleCycle` `setCyclePosition` `setCycleLength` `setCycleRegion` `wait`

**`_arrangement`** and **`_marker`** (song sections): `getMarkers` `getMarkerAt` `getMarkerByName` `count` `hasMarkers` `addMarker` `addMarkers` `removeMarkerAt` `removeMarkerByName` `setMarkers` `deleteAll`. `_marker` also has `setPositionAt` `setLengthAt` `setEndAt` `setLengthFixedAt` `renameMarkerAt` `setColorAt`.

## Other objects

- **`_regions`**: `getAll` `getByTrack` `getByName` `getByType` `getById` `getSelected` `count` `setLength` `setPosition` `trimStart` `setName` `setMuted` `setLoopEnd` `setLoopLength` `setLoopLengthFixed` `setColor` `setPitchSource` `getAvailablePitchSources` `spanOfRegions` `delete` `analyzeChords` `applyRegionChordsToChordTrack` `applyRegionTempoToProject` `applyProjectTempoToRegions` `createSmartTempoMultitrackSet` `create` `split` `convert`
- **`_converter`**: `positionAndLengthToEnd` `startAndEndToLength` `positionsEvery`
- **`_stemSeparation`**: `split`
- **`_sessionPlayer`**: `forTrack` `forRegion`, then read and write functions for character, preset, follow track, follow chords, complexity, intensity, fill complexity, fill amount, tempo, and swing. Also `setParameters` `resetParameters` `regenerate` `morphTo` `wait`.
- **`_stepSequencer`**: `forRegion` `forFocusedPattern`, then about 55 functions to read and write patterns, rows, and steps (on/off, velocity, probability, tie, skip, gate, repeats, offset, rate, pitch, loop, direction, swing, randomize).
- **`_soundsAndLoops`**: `searchLoops` `searchPatches` `loadPatchFromResult` `addLoopFromResult` `setBrowserQuery` `findSimilarLoopsInBrowser` `getBrowserResults` `getBrowserResult` `findBrowserResult` `wait`
- **`_chords`**: `getGroups` `getGroupAt` `getAllChords` `count` `chordCount` `hasChords` `deleteAll` `addGroup` `addGroups` `removeGroupAt` `setGroups` `setLoopEnd` `setLoopLength` `setLoopLengthFixed`
- **`_tempo`**: `getPoints` `getPointAt` `count` `hasPoints` `getInitialTempo` `isMetronomeOn` `getMetronomeVolume` `isCountInOn` `deleteAll` `addPoint` `addPoints` `removePointAt` `setBpmAt` `setPoints` `adjustAllByBpm` `adjustBpmAt` `turnMetronome` `setMetronomeVolume` `turnCountIn`
- **`_keySignature`**, **`_timeSignature`**: get, add, remove, and set functions for changes at positions.
- **`_projectNotes`**: `getText` `hasNotes` `setText` `clear`
- **`_projects`**: list, create, open, close, save, save as, duplicate, rename, delete, and state functions.
- **`_interface`**: `getAll` `isOpen` `open` `close` `toggle`
- **`_whatsNew`**: `getReleaseNotes`
- **`_help`**: `answer`

## Not in the API

- Sends, send levels, and bus routing
- Channel input and output assignment
- Sidechain source selection (the flag `supportsSidechain` is read-only)
- Track automation and automation modes
- Groups
- Audio data, meters, or analysis of any type
- Undo and redo

## Useful details

- Plug-ins and parameters are addressed by name. A slot number is accepted, but slot numbers change when plug-ins are added or removed.
- Parameter values are text in real units, for example a frequency in Hz.
- A channel is found through its track. An aux or bus with no track cannot be reached. The stereo output has its own function.
- A summing stack makes an aux channel that has a track. This is the one way in this API to process several tracks together.
- "Master the mix" goes to the Mastering Assistant plug-in on the stereo output.
