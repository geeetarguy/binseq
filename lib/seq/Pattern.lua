--[[------------------------------------------------------

  seq.Pattern
  -------------

  A Pattern contains:
    * list of events

  The pattern responds to
    * enable (adds itself to the sequencer)
    * disable (removes itself from the sequencer)
    * setSequencer (when assigned to a different sequencer)


--]]------------------------------------------------------
local lib = {type = 'seq.Pattern'}
lib.__index      = lib
seq.Pattern    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Pattern(...)
function lib.new(def)
  local self = def or {}

  -- Find event by event posid
  self.events      = {}

  return setmetatable(self, lib)
end

function lib:loadEvents()
  -- load events
  local events = self.events

  for e in self.db:getEvents(self.id) do
    events[e.posid] = e
  end
end

function lib:createEvent(posid)
  local e = self.db:createEvent(posid, self.id)
  self.events[posid] = e
  return e
end

function lib:save()
  -- Write event in database
  local db = self.db
  assert(db, 'Cannot save pattern without database')
  db:setPattern(self)
end

function lib:delete()
  local db = self.db
  assert(db, 'Cannot delete pattern without database')
  db:deletePattern(self)
  self.deleted = true
  for _, e in pairs(self.events) do
    e.deleted = true
  end
end

function lib:deleteEvent(e)
  e:delete()
  self.events[e.posid] = nil
end

