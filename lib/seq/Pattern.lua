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
function lib.new(song, sequencer)
  local self = {}

  -- Find event by event posid
  self.events      = {}
  -- List of all events (unsorted)
  self.events_list = {}

  if song then
    -- load events
    local events = self.events
    local list = self.events_list

    for e in song.db:getEvents(self.id) do
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
  assert(db, 'Cannot save pattern without database')
  db:setPattern(self)
end

function lib:delete()
  local db = self.db
  assert(db, 'Cannot delete pattern without database')
  db:deletePattern(self)
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

