--[[------------------------------------------------------

  test seq.Sequencer
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Sequencer')
local mock = seq.Song.mock

function should.autoLoad()
  local s = seq.Sequencer
  assertType('table', s)
end

function should.prepareListOnLoad()
  local song = mock()
  local s = song.sequencers_list[1]

  local i = 0
  local e = s.list.next
  while e do
    i = i + 1
    e = e.next
  end

  -- 48 events, 1/3 are not muted
  assertEqual(16, i)
end

function should.buildActiveList()
  local song = seq.Song(':memory:', 1)
  local aseq = song:getOrCreateSequencer(1)
  local p = song:getOrCreatePattern(1)
  aseq:enablePattern(1)
  local e = p:getOrCreateEvent(1)
  e:set {
    position = 0,  -- events 0, 96, 192
    loop = 96,
    mute = 0,
  }

  e = p:getOrCreateEvent(2)
  e:set {
    position = 24, -- events 24, 72, 120
    loop = 48,
    mute = 0,
  }

  e = p:getOrCreateEvent(3)
  e:set {
    position = 0, -- events 0, 24, 48, 72, 96
    loop = 24,
    mute = 0,
  }

  -- reading head is now at t == 8 (events at 8 are triggered)
  aseq:move(8)
  local list = aseq.list

  -- next trigger = event 2
  assertEqual(24, list.next.t)
  assertEqual(2, list.next.id)
  -- next trigger = event 3
  assertEqual(24, list.next.next.t)
  assertEqual(3, list.next.next.id)
  -- last
  assertEqual(96, list.next.next.next.t)
  assertEqual(1, list.next.next.next.id)

  aseq:move(25)
  list = aseq.list

  -- next trigger = event 3
  assertEqual(48, list.next.t)
  -- next trigger = event 2
  assertEqual(72, list.next.next.t)
  -- last
  assertEqual(96, list.next.next.next.t)
end

function should.moveOnTrigger()
  local song = seq.Song(':memory:', 1)
  local aseq = song:getOrCreateSequencer(1)
  local p = song:getOrCreatePattern(1)
  aseq:enablePattern(1)
  local e = p:getOrCreateEvent(1)
  e:set {
    position = 14,
    mute = 0,
  }
  assertEqual(0, aseq.t)
  aseq:trigger(e)
  assertEqual(14, aseq.t)
end

function should.rescheduleEventOnTrigger()
  local song = seq.Song(':memory:', 1)
  local aseq = song:getOrCreateSequencer(1)
  local p = song:getOrCreatePattern(1)
  aseq:enablePattern(1)
  local e
  e = p:getOrCreateEvent(1)
  e:set {
    position = 0,  -- events 0, 96, 192
    loop = 96,
    mute = 0,
  }

  e = p:getOrCreateEvent(2)
  e:set {
    position = 24, -- events 24, 72, 120
    loop = 48,
    mute = 0,
  }

  e = p:getOrCreateEvent(3)
  e:set {
    position = 0, -- events 0, 24, 48, 72, 96
    loop = 24,
    mute = 0,
  }

  aseq:move(8)
  list = aseq.list
  
  local triggers = {
    {2, 24},
    {3, 24},
    {3, 48},
    {2, 72},
    {3, 72},
    {1, 96},
    {3, 96},
    {2, 120},
  }

  for _, trig in ipairs(triggers) do
    local l = list.next
    assertEqual(trig[1], l.id)
    assertEqual(trig[2], l.t)
    aseq:trigger(l)
  end
end

function should.rescheduleEventOnEdit()
  local song = seq.Song(':memory:', 1)
  local aseq = song:getOrCreateSequencer(1)
  local list = aseq.list
  local p = song:getOrCreatePattern(1)
  aseq:enablePattern(1)
  local e
  e = p:getOrCreateEvent(1)

  assertNil(list.next) -- e is muted
  e:set {mute = 0}

  assertEqual(0, list.next.t)

  e = p:getOrCreateEvent(2)
  e:set {
    position = 24, -- events 24, 72, 120
    loop = 48,
    mute = 0,
  }

  assertEqual(1, list.next.id)
  assertEqual(2, list.next.next.id)
  assertNil(list.next.next.next)

  e = p:getOrCreateEvent(3)

  e:set {
    position = 10, -- events 10, 34, 58, 82, 106
    loop = 24,
    mute = 0,
  }
  assertEqual(1, list.next.id)           -- 0
  assertEqual(3, list.next.next.id)      -- 10
  assertEqual(2, list.next.next.next.id) -- 24
  assertEqual(0,  list.next.t)           -- 0
  assertEqual(10, list.next.next.t)      -- 10
  assertEqual(24, list.next.next.next.t) -- 24

  -- move existing event
  e = p:getOrCreateEvent(2)
  e:set {
    position = 5, -- events 5, 52, 101
  }

  assertEqual(1, list.next.id)           -- 0
  assertEqual(2, list.next.next.id)      -- 5
  assertEqual(3, list.next.next.next.id) -- 10
  assertEqual(0, list.next.t)            -- 0
  assertEqual(5, list.next.next.t)       -- 5
  assertEqual(10,list.next.next.next.t)  -- 10
end

function should.rescheduleEventOnEditWithT()
  local song = seq.Song(':memory:', 1)
  local aseq = song:getOrCreateSequencer(1)
  aseq:move(20)

  local list = aseq.list
  local p = song:getOrCreatePattern(1)
  aseq:enablePattern(1)
  local e
  e = p:getOrCreateEvent(1)
  e:set {
    position = 0,  -- events 0, 96, 192
    loop = 96,
    mute = 0,
  }

  e = p:getOrCreateEvent(2)
  e:set {
    position = 24, -- events 24, 72, 120
    loop = 48,
    mute = 0,
  }

  assertEqual(2, list.next.id)      -- 24
  assertEqual(1, list.next.next.id) -- 96
  assertNil(list.next.next.next)

  e = p:getOrCreateEvent(3)
  e:set {
    position = 10, -- events 10, 34, 58, 82, 106
    loop = 24,
    mute = 0,
  }
  assertEqual(2, list.next.id)           -- 24
  assertEqual(24, list.next.t)
  assertEqual(3, list.next.next.id)      -- 34
  assertEqual(34, list.next.next.t)
  assertEqual(1, list.next.next.next.id) -- 96
  assertEqual(96, list.next.next.next.t)

  e = p:getOrCreateEvent(2)
  e:set {
    position = 5, -- events 5, 52, 101
    mute = 0,
  }
  assertEqual(3, list.next.id)           -- 34
  assertEqual(2, list.next.next.id)      -- 52
  assertEqual(1, list.next.next.next.id) -- 96

  -- remove on mute
  e:set {
    mute = 1,
  }
  assertEqual(3, list.next.id)           -- 34
  assertEqual(1, list.next.next.id)      -- 52
  assertNil(list.next.next.next)
end

function should.addRemoveEventsOnPatternEnable()
  local song = seq.Song(':memory:', 1)
  local aseq = song:getOrCreateSequencer(1)
  aseq:move(20)

  local list = aseq.list
  local pat1 = song:getOrCreatePattern(1)
  local e
  e = pat1:getOrCreateEvent(1)
  e:set {
    position = 0,  -- events 0, 96, 192
    loop = 96,
    mute = 0,
  }

  e = pat1:getOrCreateEvent(2)
  e:set {
    position = 24, -- events 24, 72, 120
    loop = 48,
    mute = 0,
  }

  -- No pattern enabled yet
  assertNil(list.next)

  aseq:enablePattern(1)
  assertEqual(2, list.next.id)      -- 24
  assertEqual(1, list.next.next.id) -- 96
  assertNil(list.next.next.next)

  aseq:disablePattern(1)
  assertNil(list.next)

  local pat2 = song:getOrCreatePattern(2)
  e = pat2:getOrCreateEvent(1)
  e:set {
    position = 10, -- events 10, 34, 58, 82, 106
    loop = 24,
    mute = 0,
  }

  -- No pattern enabled yet
  assertNil(list.next)

  -- Enable pattern 1
  aseq:enablePattern(1)
  assertEqual(2, list.next.id)      -- 24
  assertEqual(1, list.next.next.id) -- 96
  assertNil(list.next.next.next)

  -- Enable pattern 1 & 2
  aseq:enablePattern(2)
  assertEqual(2, list.next.id)           -- 24
  assertEqual(24, list.next.t)
  assertEqual(3, list.next.next.id)      -- 34
  assertEqual(34, list.next.next.t)
  assertEqual(1, list.next.next.next.id) -- 96
  assertEqual(96, list.next.next.next.t)
  assertNil(list.next.next.next.next)
end

function should.setSequencerId()
  -- posid, song_id
  local song = seq.Song(':memory:', 1)
  local s = song:getOrCreateSequencer(5, 1)
  local p = song:getOrCreatePattern(3, s.id)
  s:enablePattern(p.posid)
  assertEqual(s.id, p.sequencer_id)
  -- cached version in song
  p = song.patterns[p.posid]
  assertEqual(s.id, p.sequencer_id)
  -- saved version
  p = song.db:getPattern(p.posid, song.id)
  assertEqual(s.id, p.sequencer_id)
end

function should.scheduleCtrl()
  local song = seq.Song(':memory:', 1)
  local aseq = song:getOrCreateSequencer(1)
  local pat  = song:getOrCreatePattern(1)
  aseq:enablePattern(1)
  local e = pat:getOrCreateEvent(1)

  assertValueEqual({}, aseq.ctrls)
  e:set {
    ctrl = 20,
    position = 0,  -- events 0, 96, 192
    loop = 96,
    mute = 0,
  }

  -- Not added yet (only added during note On to Off).
  assertValueEqual({}, aseq.ctrls)

  aseq:trigger(e)

  -- Added to ctrls
  assertTrue(aseq.ctrls[20][e])

  e:set {
    ctrl = 22,
  }

  -- Moved (dummy 0 value replaced because note was ON)
  assertNil(aseq.ctrls[20])
  assertEqual(e, aseq.ctrls[22][1])
end

test.all()
