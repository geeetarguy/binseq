--[[------------------------------------------------------

  test seq.Event
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Event')

function should.autoLoad()
  local e = seq.Event
  assertType('table', e)
end

function should.setDefaultsOnCreate()
  local e = seq.Event()
  assertValueEqual({
    mute     = 1,
    loop     = 24,
    position = 0,
    velocity = 80,
    note     = 0,
    length   = 6,
  }, e)
end

function should.computeTriggerTime()
  local e = seq.Event {
    position = 48,
    loop = 96,
  }
  local t = 8    -- Current time
  local Gs = 0   -- Start delta
  local Gm = nil -- Override loop length
  assertEqual(48, e:nextTrigger(t, Gs, Gm))
  t = 40
  assertEqual(48, e:nextTrigger(t, Gs, Gm))
  t = 48
  assertEqual(48, e:nextTrigger(t, Gs, Gm))
  assertEqual(96+48, e:nextTrigger(t, Gs, Gm, true))
  t = 49
  assertEqual(96+48, e:nextTrigger(t, Gs, Gm))
  -- After second loop
  t = 96 + 49
  assertEqual(96+96+48, e:nextTrigger(t, Gs, Gm))
end

function should.computeTriggerTimeWithStart()
  local e = seq.Event {
    position = 48,
    loop = 96,
  }
  local t = 8     -- Current time
  local Gs = 20   -- Start delta
  local Gm = nil  -- Override loop length
  assertEqual(28, e:nextTrigger(t, Gs, Gm))
  t = 28
  assertEqual(28, e:nextTrigger(t, Gs, Gm))
  t = 48
  assertEqual(96+28, e:nextTrigger(t, Gs, Gm))
  t = 49
  assertEqual(96+28, e:nextTrigger(t, Gs, Gm))
end

function should.computeTriggerTimeWithGlobalLoop()
  local e = seq.Event {
    position = 48,
    loop = 96,
  }
  local t = 8    -- Current time
  local Gs = 20  -- Start delta
  local Gm = 48  -- Override loop length
  assertEqual(28, e:nextTrigger(t, Gs, Gm))
  t = 28
  assertEqual(28, e:nextTrigger(t, Gs, Gm))
  t = 48+28
  assertEqual(48+28, e:nextTrigger(t, Gs, Gm))
  t = 48+29
  assertEqual(96+28, e:nextTrigger(t, Gs, Gm))
end

function should.schedule(t)
  local aseq = {}
  function aseq:schedule(e)
    self.e = e
  end

  local e = seq.Event {
    position = 48,
    mute = 0,
  }
  e:setSequencer(aseq)
  assertEqual(e, aseq.e)

  aseq.e = nil
  e:set {position = 24}
  assertEqual(e, aseq.e)

  aseq.e = nil
  e:set {loop = 24}
  assertEqual(e, aseq.e)

  aseq.e = nil
  e:set {note = 24}
  assertNil(aseq.e)
end

function should.playOnOff()
  local e = seq.Event()
  local l = 'NoteOn'
  for i=1,100 do
    local r = math.random(3)
    if r == 1 then
      e:set({length = math.random(48)})
    elseif r == 2 then
      e:set({loop = math.random(48)})
    else
      e:set({position = math.random(48)})
    end
    e:nextTrigger(e.t or 0, 0, nil)
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
  local e = seq.Event {
    loop = 24,
    length = 24,
    position = 0,
    note = 60,
  }

  -- NoteOn @ 0
  e:nextTrigger(0, 0)

  assertEqual(0, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(24, e.off_t)

  -- NoteOff @ 24
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(24, e.t)
  assertEqual(24, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)

  -- NoteOn @ 24
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(24, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(48, e.off_t)
end

function should.allowLengthDifferentAsLoop()
  local e = seq.Event {
    loop = 24,
    length = 20,
    position = 0,
    note = 60,
  }

  -- NoteOn @ 0
  e:nextTrigger(0, 0)

  assertEqual(0, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(20, e.off_t)

  -- NoteOff @ 24
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(20, e.t)
  assertEqual(20, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)

  -- NoteOn @ 24
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(24, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(44, e.off_t)

  -- change length during NoteOn
  e:set({length = 24})

  -- NoteOff @ 48
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(48, e.t)
  assertEqual(48, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)

  -- NoteOn @ 48
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(48, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(72, e.off_t)

  -- NoteOff @ 72
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(72, e.t)
  assertEqual(72, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)

  -- NoteOn @ 72, Off 96, On 96, Off 120, On 120, etc.
  for _, value in ipairs {72, 96, 96, 120, 120} do
    e:nextTrigger(e.t, 0, nil, true)
    assertEqual(value, e.t)
    e:trigger()
  end
end

function should.allowLengthLongerThenLoop()
  local e = seq.Event {
    loop = 24,
    length = 96,
    position = 0,
    note = 60,
  }

  -- NoteOn @ 0
  e:nextTrigger(0, 0)

  assertEqual(0, e.t)
  assertEqual(nil, e.off_t)
  e:trigger()
  assertEqual(96, e.off_t)

  -- NoteOff @ 24
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(24, e.t)
  -- Actual value for off_t does not matter during NoteOff
  assertEqual(96, e.off_t)
  e:trigger()
  assertEqual(nil, e.off_t)
end

function should.allowNoteChangeInNoteOn()
  local e = seq.Event {
    loop = 24,
    length = 96,
    position = 0,
    note = 60,
  }

  -- NoteOn @ 0
  e:nextTrigger(0, 0)

  assertEqual(0, e.t)
  assertEqual(nil, e.off_t)
  local _, note = e:trigger()
  assertEqual(60, note)
  assertEqual(96, e.off_t)

  e:set {note = 72}

  -- NoteOff @ 24
  e:nextTrigger(e.t, 0, nil, true)
  assertEqual(24, e.t)
  -- Actual value for off_t does not matter during NoteOff
  assertEqual(96, e.off_t)
  local a, note = e:trigger()
  assertEqual(60, note)
  assertEqual(0x80, a)

  assertEqual(nil, e.off_t)

  -- New note
  e:nextTrigger(e.t, 0, nil, true)
  local a, note = e:trigger()
  assertEqual(72, note)
  assertEqual(0x90, a)
end

local rowToPosid  = seq.Event.rowToPosid
function should.computeRowToId()
  assertEqual(1,  rowToPosid(1, 0))
  assertEqual(11, rowToPosid(3, 1))
  assertEqual(17, rowToPosid(1, 2))
end

local posidToRow  = seq.Event.posidToRow
function should.computeIdToRow()
  assertEqual(1,  posidToRow(1, 0))
  assertEqual(3,  posidToRow(11, 1))
  assertEqual(1,  posidToRow(17, 2))
  assertNil(posidToRow(1, 2))
  assertNil(posidToRow(17, 1))
end

local posidToGrid = seq.Event.posidToGrid
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

local gridToPosid = seq.Event.gridToPosid
function should.computeGridToId()
  assertEqual(1,  gridToPosid(1, 1, 0))
  assertEqual(3,  gridToPosid(1, 3, 0))
  assertEqual(27, gridToPosid(1, 3, 1))
  assertEqual(10, gridToPosid(2, 2, 0))
  assertEqual(34, gridToPosid(2, 2, 1))
end

function should.cycleThroughNotes()
  local e = seq.Event {
    position = 48,
    loop = 96,
    notes = {10,12,17,13, _len = 4},
  }
  e:nextTrigger(0, 0, nil)
  local _, n = e:trigger()
  assertEqual(10, n)
  -- NoteOff
  _, n = e:trigger()
  assertEqual(10, n)

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  _, n = e:trigger()
  assertEqual(12, n)
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
  local e = seq.Event {
    position = 48,
    loop = 96,
    velocities = {10,12,17,13, _len = 4},
  }
  e:nextTrigger(0, 0, nil)
  local _, _, n = e:trigger()
  assertEqual(10, n)
  -- NoteOff
  _, _, n = e:trigger()
  assertEqual(10, n)

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  _, _, n = e:trigger()
  assertEqual(12, n)
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
  local e = seq.Event {
    position = 48,
    loop = 96,
    lengths = {10,12,17,13, _len = 4},
  }
  e:nextTrigger(0, 0, nil)
  e:trigger()
  local n = e.off_t - e.t
  assertEqual(10, n)
  -- NoteOff
  e:trigger()

  -- Next note
  e:nextTrigger(e.t, 0, nil, true)
  e:trigger()
  n = e.off_t - e.t
  assertEqual(12, n)
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
test.all()
