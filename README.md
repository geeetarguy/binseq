# seq midi sequencer with Launchpad support

This is a brain warping tool to create midi loops that do not loop too square (one loop per note). The
only interface for this sequencer at the moment is Novation's Launchpad.

Homepage: [lubyk/seq](http://lubyk.org/en/project408.html)


# Features

Currently, the sequencer supports:

* novation Launchpad interface
* individual loop length for each note
* note value can span 7 octaves (defined via adapted binary code)
* note position can span 7 bars (defined via adapted binary code)
* chords, chord changers, chord players
* patterns (group of notes)
* up to 8 midi channels and 64 patterns

# Event types

## Note

This is the simplest event type. It is a single note that plays at regular intervals with velocity, length, etc.

## PolyNote

This is a Note with multiple values for note value, velocity or lengths. The values are used one after
the other on each trigger.

## Chord

This is an event without timing information (loop = 0). It is played by ChordPlayers. A Chord can have a single
note.

## ChordPlayer

This is an event without note (note = 0). On each trigger, the ChordPlayer plays the notes from the current
Chord. The current chord is changed by ChordChanger.

## ChordChanger

This is an event without note and velocity (note = 0, velocity = 0). On each trigger, this event does not play
any sound but selects the current chord from all the Chord events (selects them in order).

## CtrlChange (TODO)

This is like a Note but instead of playing a note with On/Off, it plays a control change starting at
value from field "note" and ending at value from field "velocity" (creates a ramp) during "length" interval.
The control value is set with the "extra" button (ctrl value is set above "note" field).
