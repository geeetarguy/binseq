--[[------------------------------------------------------

  seq.Partition
  -------------

  A partition contains events and partition settings (host
  reset, etc).

--]]------------------------------------------------------
local lib = {type = 'seq.Partition'}
lib.__index      = lib
seq.Partition    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Partition(...)
function lib.new(def)
  local self = def or {
    -- Global alterations
    note     = 0,
    velocity = 0,
    length   = 0,
    position = 0,
    loop     = 0,
  }

  -- Find event by event posid
  self.events      = {}
  -- List of all events (unsorted)
  self.events_list = {}

  if self.db then
    -- load events
    local events = self.events
    local list = self.events_list

    for e in self.db:getEvents(self.id) do
      events[e.posid] = e
      table.insert(list, e)
    end
  end

  return setmetatable(self, lib)
end

function lib:createEvent(posid)
  local e = self.db:createEvent(posid, self.id)
  table.insert(self.events_list, e)
  self.events[posid] = e
  return e
end

function lib:save()
  -- Write event in database
  local db = self.db
  assert(db, 'Cannot save partition without database')
  db:setPartition(self)
end

function lib:delete()
  local db = self.db
  assert(db, 'Cannot delete partition without database')
  db:deletePartition(self)
end

function lib:deleteEvent(e)
  e:delete()
  self.events[e.posid] = nil
  for i, le in ipairs(self.events_list) do
    if le == e then
      table.remove(self.events_list, i)
      return
    end
  end
end

