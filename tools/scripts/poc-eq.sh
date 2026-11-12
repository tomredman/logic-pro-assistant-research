#!/bin/sh
# Proof of concept: one Channel EQ change with the control surface and the Accessibility API.
#
#   1. Select the track            (Mackie Control: select button)
#   2. Open the Inspector          (Accessibility)
#   3. Insert a Channel EQ         (Accessibility: EQ button on the channel strip, only if there is no Channel EQ)
#   4. Set one band                (Accessibility: step the sliders until the readout agrees)
#   5. Read the values back        (Accessibility: readout text in real units)
#   6. Toggle bypass, twice        (Accessibility: bypass checkbox on the channel strip)
#
# Preconditions: `logic-mcu serve` is in operation and connected to Logic Pro. The track is in the
# first 8 tracks of the Mackie Control bank.
#
# Usage: poc-eq.sh <strip 1-8> <band> <freq Hz> <gain dB> <Q>
# Example: poc-eq.sh 2 "Peak 2" 250 -2.5 1.2
cd "$(dirname "$0")/.." || exit 1
A=./.build/release/logic-ax; B=./.build/release/logic-mcu
N=${1:-2}; BAND=${2:-Peak 2}; F=${3:-250}; G=${4:--2.5}; Q=${5:-1.2}
# A path can contain a space (window title). Two spaces come after the path in the dump output.
first() { sed 's/  .*//' | head -1; }
t0=$(date +%s)

# 1. Select the track.
$B send "select $N" >/dev/null || { echo "error: logic-mcu server is not in operation"; exit 1; }
sleep 1

# 2. Open the Inspector.
I=$($A dump @Tracks 1 'desc="Inspector"' | first)
if [ -z "$I" ]; then
  $A press "$($A dump @Tracks 4 'id="controlBar/inspectorButton"' | first)" >/dev/null; sleep 1.2
  I=$($A dump @Tracks 1 'desc="Inspector"' | first)
fi
[ -z "$I" ] && { echo "error: cannot open the Inspector"; exit 1; }
S=$($A dump "$I" 5 'AXLayoutItem' | first)
TRACK=$($A get "$S" | sed -n 's/^AXDescription: //p')
echo "track: $TRACK"

# 3. Insert a Channel EQ if there is none.
P=$($A dump "$S" 1 'AXGroup desc="Channel EQ"' | first)
if [ -z "$P" ]; then
  $A press "$($A dump "$S" 1 'AXButton desc="EQ"' | first)" >/dev/null; sleep 1.5
  P=$($A dump "$S" 1 'AXGroup desc="Channel EQ"' | first)
  [ -z "$P" ] && { echo "error: Channel EQ insert failed"; exit 1; }
  echo "insert: Channel EQ inserted"
else
  echo "insert: Channel EQ was there"
fi

# Open the plug-in window if it is closed.
W=$($A windows | grep "AXDialog title=\"$TRACK\"" | awk '{print $1}' | head -1)
if [ -z "$W" ]; then $A press "$($A dump "$P" 1 'desc="open"' | first)" >/dev/null; sleep 1.2; fi
EQ=$($A dump "@$TRACK" 1 'AXGroup desc="EQ"' | first)
[ -z "$EQ" ] && { echo "error: no Channel EQ window for $TRACK"; exit 1; }
param() { $A dump "$EQ" 1 "AXSlider desc=\"$1\"" | first; }
readout() { $A get "$1" | sed -n 's/^AXValueDescription: //p'; }
PF=$(param "$BAND Frequency"); PG=$(param "$BAND Gain"); PQ=$(param "$BAND Q")

# 4. Set the band. 5. Read back.
echo "before: $BAND = $(readout "$PF") / $(readout "$PG") / Q $(readout "$PQ")"
echo "set frequency $F Hz  -> $($A tune "$PF" "$F")"
echo "set gain $G dB       -> $($A tune "$PG" "$G")"
echo "set Q $Q             -> $($A tune "$PQ" "$Q")"
echo "read back: $BAND = $(readout "$PF") / $(readout "$PG") / Q $(readout "$PQ")"

# 6. Bypass on, then off. This is the A/B switch.
P=$($A dump "$S" 1 'AXGroup desc="Channel EQ"' | first)
BY=$($A dump "$P" 1 'desc="bypass"' | first)
state() { $A get "$BY" | sed -n 's/^AXValue[^:]*: //p' | head -1; }
echo "bypass: $(state)"
$A press "$BY" >/dev/null; sleep 0.4; echo "bypass after press 1: $(state)   (A: without the change)"
$A press "$BY" >/dev/null; sleep 0.4; echo "bypass after press 2: $(state)   (B: with the change)"
echo "time: $(( $(date +%s) - t0 )) s"
