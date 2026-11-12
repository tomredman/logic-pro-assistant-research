# Tools

A Swift package with two command-line tools for Logic Pro on macOS 13 or later.

```
swift build -c release
```

## logic-ax

Examine and operate Logic Pro interface elements through the Accessibility API. The process that starts it must have Accessibility permission (System Settings > Privacy & Security > Accessibility).

An element address is a path of child indexes from the application element. `@text` selects the window whose title contains the text.

```
.build/release/logic-ax trusted
.build/release/logic-ax windows
.build/release/logic-ax dump @Tracks 2                       # the tree, 2 levels
.build/release/logic-ax dump @Tracks 9 'desc="Track [0-9]+'  # only matches
.build/release/logic-ax get @Tracks.7
.build/release/logic-ax press <path>
.build/release/logic-ax tune <slider path> 250               # step until the readout is nearest to 250
```

The default target is Logic Pro Creator Studio (`com.apple.mobilelogic`), then Logic Pro (`com.apple.logic10`). Use `--bundle <id>` for a different application.

## logic-mcu

A virtual Mackie Control device. It opens two virtual MIDI ports with the name `Logic MCU`.

```
.build/release/logic-mcu selftest
.build/release/logic-mcu serve --verbose
```

Connect it one time in Logic Pro:

1. Logic Pro > Control Surfaces > Setup.
2. New > Install, select Mackie Designs / Mackie Control, then Add.
3. Set Output Port and Input Port to `Logic MCU`.

Then send commands from a second terminal:

```
.build/release/logic-mcu send "lcd"
.build/release/logic-mcu send "select 2"
.build/release/logic-mcu send "fader 1 0.75"
.build/release/logic-mcu send "state"
.build/release/logic-mcu send help
```

The connection handshake was written from knowledge of the protocol. Logic Pro accepted the device when it was added manually.

## scripts/poc-eq.sh

One Channel EQ change with the two tools. `logic-mcu serve` must be in operation.

```
scripts/poc-eq.sh 2 "Peak 2" 250 -2.5 1.2
```
