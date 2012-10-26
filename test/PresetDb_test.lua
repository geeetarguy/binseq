--[[------------------------------------------------------

  test seq.PresetDb
  -----------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.PresetDb')
local helper = {}

local gridToPosid = seq.Event.gridToPosid

function should.autoLoad()
  local e = seq.PresetDb
  assertType('table', e)
end

function should.openInMemory()
  assertPass(function()
    local db = seq.PresetDb(':memory')
  end)
end

--===================================== Partition
function should.createPartition()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p = db:createPartition(5)
  assertEqual('seq.Partition', p.type)
  assertEqual(1, p.id)
  assertEqual(5, p.posid)
  p = db:createPartition(3, 3, 0)
  assertEqual(2, p.id)
end

function should.getPartition()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p1 = db:createPartition(5)
  local p2 = db:getPartition(5)
  assertEqual(p1.id, p2.id)
  assertEqual('seq.Partition', p2.type)
  assertEqual(p1.posid, p2.posid)
end

function should.loadAllEventsOngetPartition()
  local db = helper.populateDb()
  -- row, col, page
  -- this should be partition 17
  local p = db:getPartition(3, 1, 0)
  assertEqual(17, p.id)

  -- should contain 48 events
  assertEqual(48, #p.events_list)
end

function should.updatePartition()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p = db:createPartition(5)
  assertEqual(0, p.loop)
  p.loop = 48
  p:save()
  p = db:getPartition(5)
  assertEqual(48, p.loop)
end

function should.deletePartition()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p = db:createPartition(5)
  assertEqual(0, p.loop)
  p:delete()
  p = db:getPartition(5)
  assertNil(p)
end

--===================================== Event
function should.createEvent()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local e = db:createEvent(5, 17)
  assertEqual('seq.Event', e.type)
  assertEqual(1, e.id)
  assertEqual(17, e.partition_id)
  assertEqual(5, e.posid)
  e = db:createEvent(6, 17)
  assertEqual(2, e.id)
  assertEqual(6, e.posid)
end

function should.getEvent()
  local db = seq.PresetDb(':memory')
  -- row, col, page, partition_id
  local p1 = db:createEvent(5, 17)
  local p2 = db:getEvent(5, 17)
  assertEqual(p1.id, p2.id)
  assertEqual('seq.Event', p2.type)
  assertEqual(p1.posid, p2.posid)
end

function should.updateEvent()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p = db:createEvent(5, 17)
  assertEqual(24, p.loop)
  p.loop = 48
  p:save()
  p = db:getEvent(5, 17)
  assertEqual(48, p.loop)
end

function should.deleteEvent()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local e = db:createEvent(5, 17)
  e:delete()
  e = db:getEvent(5, 17)
  assertNil(e)
end

function helper.populateDb()
  local db = seq.PresetDb(':memory')
  for row = 1,8 do
    for col = 1,8 do
      local p = db:createPartition(row, col, 0)
      --print(p.id)
    end
  end
  for _, part_id in ipairs {12, 15, 17, 1} do
    -- Only fill 6 rows = 48 events
    for row = 1,6 do
      for col = 1,8 do
        local posid = seq.Event.gridToPosid(row, col, 0)
        local e = db:createEvent(posid, part_id)
      end
    end
  end
  return db
end

test.all()
