--[[------------------------------------------------------

  test binseq.Event
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.Event')

function should.autoLoad()
  local e = binseq.Event
  assertType('table', e)
end

function should.setDefaultsOnCreate()
  local e = binseq.Event()
  assertValueEqual({
    mute     = 1,
    loop     = 24,
    position = 0,
    velocity = 80,
    note     = 0,
    length   = 6,
    index    = {},
    etype    = 'note',
  }, e)
end

function should.computeTriggerTime()
  local e = binseq.Event {
    position = 48,
    loop = 96,
  }
  local t = 8    -- Current time
  local Gs = 0   -- Start delta
  local Gm = nil -- Override loop length
  assertEqual(48, e:nextTrigger(t))
  t = 40
  assertEqual(48, e:nextTrigger(t))
  t = 48
  assertEqual(48, e:nextTrigger(t))
  assertEqual(96+48, e:nextTrigger(t, Gs, Gm, true))
  t = 49
  assertEqual(96+48, e:nextTrigger(t))
  -- After second loop
  t = 96 + 49
  assertEqual(96+96+48, e:nextTrigger(t))
end

function should.computeTriggerTimeWithDelta()
  local e = binseq.Event {
    position = 48,
    loop = 96,
  }
  local pat = binseq.Pattern()
  e.pat = pat
  pat.position = 10
  local t = 8     -- Current time
  assertEqual(58, e:nextTrigger(t))
  t = 58
  assertEqual(58, e:nextTrigger(t))
  t = 59
  assertEqual(96+58, e:nextTrigger(t))
end

function should.computeTriggerTimeWithGlobalLoop()
  local e = binseq.Event {
    position = 48,
    loop = 128,
  }
  local pat = binseq.Pattern()
  e.pat = pat
  pat.loop = 100
  local t = 8    -- Current time
  assertEqual(48, e:nextTrigger(t))
  t = 48
  assertEqual(48, e:nextTrigger(t))
  t = 100+28
  assertEqual(148, e:nextTrigger(t))
end

function should.computeVelocityWithGlobal()
  local e = binseq.Event {
    position = 48,
    loop = 128,
    velocity = 20,
    note = 65,
  }
  local pat = binseq.Pattern()
  e.pat = pat
  pat.note   = 0
  pat.velocity = 48
  e:nextTrigger(0)
  local a, b, c = e:trigger()
  assertEqual(65, b)
  assertEqual(48+20, c)
  pat.velocity = 127
  a, b, c = e:trigger()
  assertEqual(65, b)
  assertEqual(127, c)
end

function should.reSchedule(t)
  local aseq = {}
  function aseq:reSchedule(e)
    self.test_e = e
  end

  local e = binseq.Event {
    position = 48,
    mute = 0,
  }
  -- Need to be part of a pattern to be scheduled.
  e.pat = binseq.Pattern()

  e:setSequencer(aseq)
  assertEqual(e, aseq.test_e)

  aseq.test_e = nil
  e:set {position = 12}
  assertEqual(e, aseq.test_e)

  aseq.test_e = nil
  e:set {loop = 24}
  assertEqual(e, aseq.test_e)

  aseq.test_e = nil
  e:set {note = 24}
  assertNil(aseq.test_e)
end

function should.playOnOff()
  local e = binseq.Event()
  e.note = 40
  e.pat = binseq.Pattern()
  local l = 'NoteOn'
  for i=1,100 do
    local r = math.random(3)
    if r == 1 then
      e:set({length = 1 + math.random(48)})
    elseif r == 2 then
      e:set({loop = 1 + math.random(48)})
    else
      e:set({position = 1 + math.random(48)})
    end
    e:nextTrigger(e.t or 0)
    local a
    if e.t or l == 'NoteOff' then
      a = e:trigger()
      if l == 'NoteOn' then
        assertEqual(0x90, a)
        l = 'NoteOff'
      else
        assertEqual(0x80, a)
        l = 'NoteOn'
      end
    end
  end
end

function should.allowLengthSameAsLoop()
  local e = binseq.Event {
    loop = 24,
    length = 24,
    position = 0,
    note = 60,
  }
  e.pat = binseq.Pattern()

  -- NoteOn @ 0
  e:nextTrigger(0)

  assertEqual(0, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(24, e.off_t)

  -- NoteOff @ 24
  e:nextTrigger(e.t, true)
  assertEqual(24, e.t)
  assertEqual(24, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)

  -- NoteOn @ 24
  e:nextTrigger(e.t, true)
  assertEqual(24, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(48, e.off_t)
end

function should.allowLengthDifferentAsLoop()
  local e = binseq.Event {
    loop = 24,
    length = 20,
    position = 0,
    note = 60,
  }
  e.pat = binseq.Pattern()

  -- NoteOn @ 0
  e:nextTrigger(0)

  assertEqual(0, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(20, e.off_t)

  -- NoteOff @ 24
  e:nextTrigger(e.t, true)
  assertEqual(20, e.t)
  assertEqual(20, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)

  -- NoteOn @ 24
  e:nextTrigger(e.t, true)
  assertEqual(24, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(44, e.off_t)

  -- change length during NoteOn
  e:set({length = 24})

  -- NoteOff @ 48
  e:nextTrigger(e.t, true)
  assertEqual(48, e.t)
  assertEqual(48, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)

  -- NoteOn @ 48
  e:nextTrigger(e.t, true)
  assertEqual(48, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(72, e.off_t)

  -- NoteOff @ 72
  e:nextTrigger(e.t, true)
  assertEqual(72, e.t)
  assertEqual(72, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)

  -- NoteOn @ 72, Off 96, On 96, Off 120, On 120, etc.
  for _, value in ipairs {72, 96, 96, 120, 120} do
    e:nextTrigger(e.t, true)
    assertEqual(value, e.t)
    e:trigger()
  end
end

function should.allowLengthLongerThenLoop()
  local e = binseq.Event {
    loop = 24,
    length = 96,
    position = 0,
    note = 60,
  }
  e.pat = binseq.Pattern()

  -- NoteOn @ 0
  e:nextTrigger(0)

  assertEqual(0, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(96, e.off_t)

  -- NoteOff @ 24
  e:nextTrigger(e.t, true)
  assertEqual(24, e.t)
  -- Actual value for off_t does not matter during NoteOff
  assertEqual(96, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)
end

function should.allowNoteChangeInNoteOn()
  local e = binseq.Event {
    loop = 24,
    length = 96,
    position = 0,
    note = 60,
  }
  e.pat = binseq.Pattern()
  e.pat.note = 0

  -- NoteOn @ 0
  e:nextTrigger(0)

  assertEqual(0, e.t)
  assertEqual(nil, e.off_t)
  local _, note = e:trigger()
  assertEqual(60, note)
  assertEqual(96, e.off_t)

  e:set {note = 72}

  -- NoteOff @ 24
  e:nextTrigger(e.t, true)
  assertEqual(24, e.t)
  -- Actual value for off_t does not matter during NoteOff
  assertEqual(96, e.off_t)
  local a, note = e:trigger()
  assertEqual(60, note)
  assertEqual(0x80, a)

  assertEqual(nil, e.off_t)

  -- New note
  e:nextTrigger(e.t, true)
  local a, note = e:trigger()
  assertEqual(72, note)
  assertEqual(0x90, a)
end

local rowToPosid  = binseq.Event.rowToPosid
function should.computeRowToId()
  assertEqual(1,  rowToPosid(1, 0))
  assertEqual(11, rowToPosid(3, 1))
  assertEqual(17, rowToPosid(1, 2))
end

local posidToRow  = binseq.Event.posidToRow
function should.computeIdToRow()
  assertEqual(1,  posidToRow(1, 0))
  assertEqual(3,  posidToRow(11, 1))
  assertEqual(1,  posidToRow(17, 2))
  assertNil(posidToRow(1, 2))
  assertNil(posidToRow(17, 1))
end

local posidToGrid = binseq.Event.posidToGrid
local function assertPairEqual(a, b, c, d)
  assertEqual(a, c)
  assertEqual(b, d)
end

function should.computeIdToGrid()
  assertPairEqual(1, 1, posidToGrid(1, 0, 3))
  assertPairEqual(1, 3, posidToGrid(3, 0, 3))
  assertPairEqual(3, 1, posidToGrid(17, 0, 3))
  assertPairEqual(2, 2, posidToGrid(34, 1, 3))
  assertNil(posidToGrid(1, 1, 3))
  assertNil(posidToGrid(25, 0, 3))
end

local gridToPosid = binseq.Event.gridToPosid
function should.computeGridToId()
  assertEqual(1,  gridToPosid(1, 1, 0))
  assertEqual(3,  gridToPosid(1, 3, 0))
  assertEqual(27, gridToPosid(1, 3, 1))
  assertEqual(10, gridToPosid(2, 2, 0))
  assertEqual(34, gridToPosid(2, 2, 1))
end

function should.cycleThroughNotes()
  local e = binseq.Event {
    position = 48,
    loop = 96,
    notes = {10,12,17,13, _len = 4},
  }
  e.pat = binseq.Pattern()
  e.pat.note = 0

  e:nextTrigger(0, 0, nil)
  local _, n = e:trigger()
  assertEqual(10, n)
  assertEqual(1, e.index.note)
  -- NoteOff
  _, n = e:trigger()
  assertEqual(10, n)
  assertEqual(1, e.index.note)

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  _, n = e:trigger()
  assertEqual(12, n)
  assertEqual(2, e.index.note)
  -- NoteOff
  _, n = e:trigger()
  assertEqual(12, n)

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  _, n = e:trigger()
  assertEqual(17, n)
  -- NoteOff
  _, n = e:trigger()
  assertEqual(17, n)
  
  -- Indepotent
  -- Song move
  e:nextTrigger(0, 0, nil)
  _, n = e:trigger()
  assertEqual(10, n)
  -- NoteOff
  _, n = e:trigger()
  assertEqual(10, n)
end

function should.cycleThroughVelocities()
  local e = binseq.Event {
    position = 48,
    loop = 96,
    velocities = {10,12,17,13, _len = 4},
  }
  e.pat = binseq.Pattern()
  e.pat.note = 0

  e:nextTrigger(0, 0, nil)
  local _, _, n = e:trigger()
  assertEqual(10, n)
  assertEqual(1, e.index.velocity)
  -- NoteOff
  _, _, n = e:trigger()
  assertEqual(10, n)
  assertEqual(1, e.index.velocity)

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  _, _, n = e:trigger()
  assertEqual(12, n)
  assertEqual(2, e.index.velocity)
  -- NoteOff
  _, _, n = e:trigger()
  assertEqual(12, n)

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  _, _, n = e:trigger()
  assertEqual(17, n)
  -- NoteOff
  _, _, n = e:trigger()
  assertEqual(17, n)
  
  -- Indepotent
  -- Song move
  e:nextTrigger(0, 0, nil)
  _, _, n = e:trigger()
  assertEqual(10, n)
  -- NoteOff
  _, _, n = e:trigger()
  assertEqual(10, n)
end

function should.cycleThroughLengths()
  local e = binseq.Event {
    position = 48,
    loop = 96,
    lengths = {10,12,17,13, _len = 4},
  }
  e.pat = binseq.Pattern()
  e.pat.note = 0

  e:nextTrigger(0, 0, nil)
  e:trigger()
  local n = e.off_t - e.t
  assertEqual(10, n)
  assertEqual(1, e.index.length)
  -- NoteOff
  e:trigger()
  assertEqual(1, e.index.length)

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  e:trigger()
  n = e.off_t - e.t
  assertEqual(12, n)
  assertEqual(2, e.index.length)
  -- NoteOff
  e:trigger()

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  e:trigger()
  n = e.off_t - e.t
  assertEqual(17, n)
  -- NoteOff
  e:trigger()
  
  -- Indepotent
  -- Song move
  e:nextTrigger(0, 0, nil)
  e:trigger()
  n = e.off_t - e.t
  assertEqual(10, n)
  -- NoteOff
  e:trigger()
end

function should.dumpEvent()
  local db = binseq.PresetDb(':memory:')
  local song = db:getOrCreateSong(5)
  local pat  = song:getOrCreatePattern(6)
  local e = pat:getOrCreateEvent(10)
  e:set {
    note = 1,
    velocity = 2,
    length = 3,
    position = 4,
    loop = 5,
    mute = 0,
  }
  local p = e:dump()
  assertEqual('binseq.Event', p.type)
  assertValueEqual({
    note = 1,
    velocity = 2,
    length = 3,
    position = 4,
    loop = 5,
    mute = 0,
  }, p.data)
end

test.all()
