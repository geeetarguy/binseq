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
    loop     = 24,
    position = 0,
    velocity = 48,
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

function should.setEvent()
  local e = seq.Event {
    position = 48
  }
  assertTrue(e:set({position = 24}))
  assertTrue(e:set({loop = 24}))
  assertFalse(e:set({note = 24}))
end

test.all()
