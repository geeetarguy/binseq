--[[------------------------------------------------------

  test seq.Pattern
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Pattern')

function should.autoLoad()
  local e = seq.Pattern
  assertType('table', e)
end

function should.createPattern()
  local s
end

function should.loadEvents()
  local s = seq.Song.mock()
  local db = s.db
  local p = db:getOrCreatePattern(17, s.id)
  p:loadEvents()
  local i = 0
  for _, e in pairs(p.events) do
    i = i + 1
  end
  assertEqual(48, i)
end

function should.addEventToChordChangers()
  local db = seq.PresetDb ':memory'
  local pat = db:getOrCreatePattern(1, 1)
  local e = pat:getOrCreateEvent(1)
  assertValueEqual({}, pat.chord_changers)
  e:set {
    note     = 0,
    velocity = 0,
  }
  assertEqual(pat, e.pat)
  assertTrue(e.chord_changer)
  assertEqual(e, pat.chord_changers[1])
end

function should.removeEventFromChordChangers()
  local db = seq.PresetDb ':memory'
  local pat = db:getOrCreatePattern(1, 1)
  local e = pat:getOrCreateEvent(1)
  assertValueEqual({_len = 0}, pat.chords)
  e:set {
    notes = {60, 63, 67},
    loop  = 0,
  }
  assertEqual(1, pat.chords._len)
  e:set {
    loop  = 48,
  }
  assertNil(pat.chords[1])
  assertEqual(0, pat.chords._len)
end

function should.addEventToChords()
  local db = seq.PresetDb ':memory'
  local pat = db:getOrCreatePattern(1, 1)
  local e = pat:getOrCreateEvent(1)
  assertValueEqual({_len = 0}, pat.chords)
  e:set {
    notes = {60, 63, 67},
    loop  = 0,
  }
  assertTrue(e.is_chord)
  assertEqual(1, pat.chords._len)
  assertEqual(e, pat.chords[1])
end

function should.removeEventFromChords()
  local db = seq.PresetDb ':memory'
  local pat = db:getOrCreatePattern(1, 1)
  local e = pat:getOrCreateEvent(1)
  assertValueEqual({_len = 0}, pat.chords)
  e:set {
    notes = {60, 63, 67},
    loop  = 0,
  }
  assertEqual(1, pat.chords._len)
  e:set {
    loop  = 48,
  }
  assertNil(pat.chords[1])
  assertEqual(0, pat.chords._len)
end


function chordPattern()
  local db = seq.PresetDb ':memory'
  local pat = db:getOrCreatePattern(1, 1)
  -- Chord notes
  local e1 = pat:getOrCreateEvent(1)
  local e2 = pat:getOrCreateEvent(2)
  local e3 = pat:getOrCreateEvent(3)
  -- Rhythm
  local r1 = pat:getOrCreateEvent(4)
  local r2 = pat:getOrCreateEvent(5)
  local r3 = pat:getOrCreateEvent(6)
  local r4 = pat:getOrCreateEvent(7)
  -- Chord changers
  local c1 = pat:getOrCreateEvent(8)
  local c2 = pat:getOrCreateEvent(9)

  -- C-  (60, 63, 67)
  e1.notes = {60, 63, 67, _len = 3}
  -- treat as chord
  e1.loop  = 0

  -- F-  (60, 65, 68)
  e2.notes = {60, 65, 68, _len = 3}
  e2.loop  = 0

  -- G7  (59, 62, 65)
  e3.notes = {59, 62, 65, _len = 3}
  e3.loop  = 0

  -- Rhythm
  -- Do not play any note (chord trigger)
  -- Every bar 
  r1.loop = 96
  r1.position = 0
  r1.note  = 0

  -- Every bar on 3
  r2.loop = 96
  r2.position = 48
  r2.note  = 0

  -- Every bar on 3+ 
  r3.loop = 96
  r3.position = 60
  r3.note  = 0

  -- Every bar on 4 
  r4.loop = 96
  r4.position = 72
  r4.note  = 0

  -- Change chord every 2 bar
  -- Ignore as chord note
  c1.note     = 0
  -- Mark as chord changer
  c1.velocity = 0
  c1.loop = 192

  -- Change chord at bar 3 every 4
  c2.note = 0
  c2.velocity = 0
  c2.loop = 384
  c2.position = 288

  local partition = {
    events = {
      e = {e1, e2, e3, e4},
      r = {r1, r2, r3, r4},
      c = {c1, c2},
    },
    -- 1st bar
    [0  ] = {e=r1, chord = {60, 63, 67}},
    [48 ] = {e=r2, chord = {60, 63, 67}},
    [60 ] = {e=r3, chord = {60, 63, 67}},
    [72 ] = {e=r4, chord = {60, 63, 67}},
    -- 2nd bar
    [96 ] = {e=r1, chord = {60, 63, 67}},
    [144] = {e=r2, chord = {60, 63, 67}},
    [156] = {e=r3, chord = {60, 63, 67}},
    [168] = {e=r4, chord = {60, 63, 67}},
    -- CHORD CHANGE AFTER BAR 2
    -- 3rd bar
    [192] = {e=r1, chord = {63, 65, 62}},
    [240] = {e=r2, chord = {63, 65, 62}},
    [252] = {e=r3, chord = {63, 65, 62}},
    [264] = {e=r4, chord = {63, 65, 62}},
    -- CHORD CHANGE AFTER BAR 3
    -- 4th bar
    [288] = {e=r1, chord = {67, 68, 65}},
    [336] = {e=r2, chord = {67, 68, 65}},
    [348] = {e=r3, chord = {67, 68, 65}},
    [360] = {e=r4, chord = {67, 68, 65}},
    -- CHORD CHANGE AFTER BAR 4
    -- 5th bar == 1st bar
    [384] = {e=r1, chord = {60, 63, 67}},
    [432] = {e=r2, chord = {60, 63, 67}},
    [444] = {e=r3, chord = {60, 63, 67}},
    [456] = {e=r4, chord = {60, 63, 67}},
  }
  return pat, partition
end

function should.useAsChord()
  local pat, partition = chordPattern()

  for _, e in ipairs(partition.events.r) do
    -- t, Gs
    e:nextTrigger(0, 0)
  end

  for t=0,500 do
    local event = partition[t]
    if event then
      local e = event.e
      local notes = event.chord
      -- Ensure Rhythmic events are correct.
      assertEqual(t, e.t)
      e:nextTrigger(t, 0, nil, true)
    end
  end
end

test.all()

