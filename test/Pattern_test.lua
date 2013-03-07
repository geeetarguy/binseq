--[[------------------------------------------------------

  test binseq.Pattern
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.Pattern')

function should.autoLoad()
  local e = binseq.Pattern
  assertType('table', e)
end

function should.createPattern()
  local s
end

function should.loadEvents()
  local s = binseq.Song.mock()
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
  local db = binseq.Database ':memory:'
  local pat = db:getOrCreatePattern(1, 1)
  local e = pat:getOrCreateEvent(1)
  assertValueEqual({}, pat.chord_changers)
  e:set {
    note     = 0,
    velocity = 0,
  }
  assertEqual(pat, e.pat)
  assertEqual('chord_changer', e.etype)
  assertEqual(e, pat.chord_changers[1])
end

function should.removeEventFromChordChangers()
  local db = binseq.Database ':memory:'
  local pat = db:getOrCreatePattern(1, 1)
  local e = pat:getOrCreateEvent(1)
  assertValueEqual({_len = 0}, pat.chords)
  e:set {
    notes = {60, 63, 67},
    loop  = 0,
  }
  assertEqual(1, pat.chords._len)
  assertEqual(e, pat.chords[1])
  e:set {
    loop  = 48,
  }
  assertNil(pat.chords[1])
  assertEqual(0, pat.chords._len)
end

function should.addEventToChords()
  local db = binseq.Database ':memory:'
  local pat = db:getOrCreatePattern(1, 1)
  local e = pat:getOrCreateEvent(1)
  assertValueEqual({_len = 0}, pat.chords)
  e:set {
    notes = {60, 63, 67},
    loop  = 0,
  }
  assertEqual('chord', e.etype)
  assertEqual(1, pat.chords._len)
  assertEqual(e, pat.chords[1])
end

function should.removeEventFromChords()
  local db = binseq.Database ':memory:'
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
  local db = binseq.Database ':memory:'
  local pat = db:getOrCreatePattern(1, 1)
  pat.note = 0
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
  e1:set {
    notes = {60, 63, 67, _len = 3},
    -- treat as chord
    loop  = 0,
    mute  = 0,
  }

  -- F-  (60, 65, 68)
  e2:set {
    notes = {60, 65, 68, _len = 3},
    loop  = 0,
    mute  = 0,
  }

  -- G7  (59, 62, 65)
  e3:set {
    notes = {59, 62, 65, _len = 3},
    loop  = 0,
    mute  = 0,
  }

  -- Rhythm
  -- Do not play any note (chord trigger)
  -- Every bar 
  r1:set {
    loop = 96,
    position = 0,
    note  = 0,
    mute  = 0,
  }

  -- Every bar on 3
  r2:set {
    loop = 96,
    position = 48,
    note  = 0,
    mute  = 0,
  }

  -- Every bar on 3+ 
  r3:set {
    loop = 96,
    position = 60,
    note  = 0,
    mute  = 0,
  }

  -- Every bar on 4 
  r4:set {
    loop = 96,
    position = 72,
    note  = 0,
    mute  = 0,
  }

  -- Change chord every 2 bar
  -- Ignore as chord note
  c1:set {
    note     = 0,
    -- Mark as chord changer
    velocity = 0,
    loop = 192,
    mute  = 0,
  }

  -- Change chord at bar 3 every 4
  c2:set {
    note = 0,
    velocity = 0,
    loop = 384,
    position = 288,
    mute  = 0,
  }

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
    [192] = {e=r1, chord = {60, 65, 68}},
    [240] = {e=r2, chord = {60, 65, 68}},
    [252] = {e=r3, chord = {60, 65, 68}},
    [264] = {e=r4, chord = {60, 65, 68}},
    -- CHORD CHANGE AFTER BAR 3
    -- 4th bar
    [288] = {e=r1, chord = {59, 62, 65}},
    [336] = {e=r2, chord = {59, 62, 65}},
    [348] = {e=r3, chord = {59, 62, 65}},
    [360] = {e=r4, chord = {59, 62, 65}},
    -- CHORD CHANGE AFTER BAR 4
    -- 5th bar == 1st bar
    [384] = {e=r1, chord = {60, 63, 67}},
    [432] = {e=r2, chord = {60, 63, 67}},
    [444] = {e=r3, chord = {60, 63, 67}},
    [456] = {e=r4, chord = {60, 63, 67}},
  }
  return pat, partition
end

function should.computeChordIndex()
  local pat, partition = chordPattern()

  assertEqual(3, pat.chords._len)

  -- Chord changers:
  -- c1.loop = 192
  -- c2.loop = 384
  -- c2.position = 288
  -- ==> [0, 192, 288, 384, 576, 672]
  local index_for_t = {
    [0] = 1,
    -- anything in between is 1
    [5] = 1,
    [100] = 1,
    [191] = 1,
    -- change
    [192] = 2,
    [193] = 2,
    -- change
    [288] = 3,
    [298] = 3,
    -- change
    [384] = 1,
    [387] = 1,
    -- change
    [576] = 2,
    -- change
    [672] = 3,
  }
  --
  for t, idx in pairs(index_for_t) do
    assertEqual(idx, pat:chordIndex(t))
  end

end

function should.useAsChord()
  local pat, partition = chordPattern()

  for _, e in ipairs(partition.events.r) do
    -- t, Gs
    e:nextTrigger(0)
  end

  for t=0,500 do
    local event = partition[t]
    if event then
      local e = event.e
      local notes = event.chord
      -- Ensure Rhythmic events are correct.
      assertEqual(t, e.t)
      e:nextTrigger(t, true)
    end
  end
end

function should.playChord()
  local pat, partition = chordPattern()
  -- rhythm events
  local r = partition.events.r

  for _, e in ipairs(partition.events.r) do
    -- t, Gs
    e:nextTrigger(0)
    assertEqual('chord_player', e.etype)
  end

  for t=0,500 do
    local event = partition[t]
    if event then
      local e = event.e
      local chord = event.chord
      -- NoteOn
      assertNil(e.off_t)
      local midi = e:trigger()
      assertEqual(3, #midi)
      for i=1,3 do 
        assertEqual(144, midi[i][1])
        assertEqual(chord[i], midi[i][2])
      end
      -- Prepare Note Off
      e:nextTrigger(e.t, true)
      assertTrue(e.off_t)
      -- NoteOff
      local midi = e:trigger()
      for i=1,3 do 
        assertEqual(128, midi[i][1])
        assertEqual(chord[i], midi[i][2])
      end
      assertNil(e.off_t)
      -- Prepare next note
      e:nextTrigger(e.t, true)
    end
  end
 
end

function should.savePatternTuning()
  local db = binseq.Database(':memory:')
  local song = db:getOrCreateSong(5)
  local pat  = song:getOrCreatePattern(6)
  local glo = pat.global
  glo:set {
    note = 4,
  }

  local p2 = db:getPattern(6, song.id)
  assertEqual(4, p2.note)
end

function should.savePatternLoop()
  local db = binseq.Database(':memory:')
  local song = db:getOrCreateSong(5)
  local pat  = song:getOrCreatePattern(6)
  local glo = pat.global
  glo:set {
    loop = 48,
  }

  local p2 = db:getPattern(6, song.id)
  assertEqual(48, p2.loop)
end

function should.savePatternPosition()
  local db = binseq.Database(':memory:')
  local song = db:getOrCreateSong(5)
  local pat  = song:getOrCreatePattern(6)
  local glo = pat.global
  glo:set {
    position = 10,
  }

  local p2 = db:getPattern(6, song.id)
  assertEqual(10, p2.position)
end

function should.savePatternVelocity()
  local db = binseq.Database(':memory:')
  local song = db:getOrCreateSong(5)
  local pat  = song:getOrCreatePattern(6)
  local glo = pat.global
  glo:set {
    velocity = 16,
  }

  local p2 = db:getPattern(6, song.id)
  assertEqual(16, p2.velocity)
end

function should.reScheduleEventsOnGlobal()
  local db = binseq.Database(':memory:')
  local song = db:getOrCreateSong(5)
  local pat  = song:getOrCreatePattern(6)
  local e = pat:getOrCreateEvent(10)
  local glo = pat.global
  local aseq = binseq.Sequencer()
  e.note = 40
  pat:setSequencer(aseq)
  function aseq:reSchedule(e)
    aseq.test_e = e
  end

  assertNil(aseq.test_e)

  glo:set {
    position = 10,
  }
  assertEqual(e, aseq.test_e)
end

function should.dumpPattern()
  local db = binseq.Database(':memory:')
  local song = db:getOrCreateSong(5)
  local pat  = song:getOrCreatePattern(6)
  local e = pat:getOrCreateEvent(10)
  e:set {
    note = 11,
    velocity = 12,
    length = 13,
    position = 14,
    loop = 15,
    mute = 0,
  }
  pat.global:set {
    note = 1,
    velocity = 2,
    position = 3,
    loop = 4,
  }
  local p = pat:dump()
  assertEqual('binseq.Pattern', p.type)
  assertValueEqual({
    note = 1,
    velocity = 2,
    position = 3,
    loop = 4,
  }, p.data)
  assertValueEqual({
    ['10'] = {
      type = 'binseq.Event',
      data = {
        note = 11,
        velocity = 12,
        length = 13,
        position = 14,
        loop = 15,
        mute = 0,
      }
    }
  }, p.events)
end

test.all()

