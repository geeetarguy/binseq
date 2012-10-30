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
  local song = seq.Song(':memory', 1)
  local aseq = song:getOrCreateSequencer(1)
  local p = song:getOrCreatePattern(1)
  aseq:enablePattern(1)
  local e = p:getOrCreateEvent(1)
  e:set {
    position = 0,  -- events 0, 96, 192
    loop = 96,
  }

  e = p:getOrCreateEvent(2)
  e:set {
    position = 24, -- events 24, 72, 120
    loop = 48,
  }

  e = p:getOrCreateEvent(3)
  e:set {
    position = 0, -- events 0, 24, 48, 72, 96
    loop = 24,
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
  local song = seq.Song(':memory', 1)
  local aseq = song:getOrCreateSequencer(1)
  local p = song:getOrCreatePattern(1)
  aseq:enablePattern(1)
  local e = p:getOrCreateEvent(1)
  e:set {
    position = 14,
  }
  assertEqual(0, aseq.t)
  aseq:trigger(e)
  assertEqual(14, aseq.t)
end

--[[

function should.rescheduleEventOnTrigger()
  local s = seq.Sequencer(':memory')
  s:setEvent(1, {
    position = 0,  -- events 0, 96, 192
    loop = 96,
  })

  s:setEvent(2, {
    position = 24, -- events 24, 72, 120
    loop = 48,
  })

  s:setEvent(3, {
    position = 0, -- events 0, 24, 48, 72, 96
    loop = 24,
  })

  local t = 8
  local list = s:buildActiveList(t)
  local l
  
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
    l = list.next
    assertEqual(trig[1], l.id)
    assertEqual(trig[2], l.t)
    s:trigger(l)
  end
end

function should.rescheduleEventOnEdit()
  local s = seq.Sequencer(':memory')
  s:setEvent(1, {
    position = 0,  -- events 0, 96, 192
    -- default loop = 96
  })

  s:setEvent(2, {
    position = 24, -- events 24, 72, 120
    loop = 48,
  })

  local list = s.list
  assertEqual(1, list.next.id)
  assertEqual(2, list.next.next.id)
  assertNil(list.next.next.next)

  s:setEvent(3, {
    position = 10, -- events 10, 34, 58, 82, 106
    loop = 24,
  })
  assertEqual(1, list.next.id)           -- 0
  assertEqual(3, list.next.next.id)      -- 10
  assertEqual(2, list.next.next.next.id) -- 24

  s:setEvent(2, {
    position = 5, -- events 5, 52, 101
  })
  assertEqual(1, list.next.id)           -- 0
  assertEqual(2, list.next.next.id)      -- 5
  assertEqual(3, list.next.next.next.id) -- 10
end

function should.rescheduleEventOnEditWithT()
  local s = seq.Sequencer(':memory')
  s.t = 20
  s:setEvent(1, {
    position = 0,  -- events 0, 96, 192
    loop = 96,
  })

  s:setEvent(2, {
    position = 24, -- events 24, 72, 120
    loop = 48,
  })

  local list = s.list
  assertEqual(2, list.next.id)      -- 24
  assertEqual(1, list.next.next.id) -- 96
  assertNil(list.next.next.next)

  s:setEvent(3, {
    position = 10, -- events 10, 34, 58, 82, 106
    loop = 24,
  })
  assertEqual(2, list.next.id)           -- 24
  assertEqual(24, list.next.t)
  assertEqual(3, list.next.next.id)      -- 34
  assertEqual(34, list.next.next.t)
  assertEqual(1, list.next.next.next.id) -- 96
  assertEqual(96, list.next.next.next.t)

  s:setEvent(2, {
    position = 5, -- events 5, 52, 101
  })
  assertEqual(3, list.next.id)           -- 34
  assertEqual(2, list.next.next.id)      -- 52
  assertEqual(1, list.next.next.next.id) -- 96
end
--]]

test.all()
