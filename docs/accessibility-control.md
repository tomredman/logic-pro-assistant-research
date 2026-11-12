# Control of Logic Pro through the Accessibility API

Tested on Logic Pro Creator Studio 13.0 with the tools in this repository.

## What the Accessibility tree gives

**Track headers.** A group with the description "Tracks header" contains one item for each track, with the description `Track N "Name"`. Its `AXSelectedChildren` attribute is writable. A write selects the track.

**Inspector channel strip.** With the Inspector open, the strip of the selected track gives named controls:

- name, mute, solo, record, monitoring
- volume fader, with the level as text ("0.0 dB")
- pan
- automation mode
- group
- output
- send button
- empty plug-in slots
- for each inserted plug-in: a group with the plug-in name, a bypass checkbox, and an open button
- an EQ button. A press inserts a Channel EQ if the strip has none.

**Stock plug-in windows.** The Channel EQ window gives each parameter as a named slider ("Peak 2 Frequency") with:

- a raw value, a minimum, and a maximum
- a readout in real units in the value description ("250 Hz", "-2.5 dB", "1.20")
- a checkbox for each band

## Important behavior

- **One step for each write.** A write to a slider value moves the slider one step in the direction of the written value. It does not jump. To get a target, write again until the readout agrees. A change across the full frequency range took 325 steps and less than 1 second.
- **Window indexes change.** The order of the windows changes when windows open or come to the front. Address a window by its title.
- **The strip is built again after a selection change.** Wait until its controls are there.
- **The plug-in menu is not in the tree.** A press on an empty slot gives a timeout result, and no menu element shows. Thus we could not insert a plug-in other than Channel EQ. This is an open problem.

## Proof of concept

`tools/scripts/poc-eq.sh` does one full change:

1. Select the track.
2. Open the Inspector.
3. Insert a Channel EQ if there is none.
4. Set frequency, gain, and Q of one band.
5. Read the values back.
6. Toggle bypass on and off.

Result: target 250 Hz, -2.5 dB, Q 1.2. Read back: 250 Hz, -2.5 dB, Q 1.20. Time: 3 seconds.

## Mackie Control

A virtual Mackie Control device (`logic-mcu`) connects without problems. Track names, fader positions, and the track select buttons operate correctly. The plug-in and EQ assignment views did not respond in our tests. The Accessibility path made them unnecessary.

## Comparison with the internal assistant API

| Function | Internal API | Accessibility |
|---|---|---|
| Insert Channel EQ | Yes | Yes |
| Insert other plug-ins | Yes | Not yet |
| Set parameters by name in real units | Yes | Yes, by steps |
| Read values back | Possible, but the assistant did not do it | Yes |
| Bypass | Yes | Yes |
| Sends, output, group, automation mode | No | Controls are visible. Not tested. |
