--[[------------------------------------------------------

  seq.Song
  -------------

  A song contains
    * 64 patterns
    * 1 to 8 sequencers

  The song responds to
    * play(t): trigger events for all sequencers
    * move(t): change song position
    * enablePattern(posid): turn pattern On 
    * disablePattern(posid): turn pattern Off
    
--]]------------------------------------------------------
local lib = {type = 'seq.Song'}
lib.__index      = lib
seq.Song    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

function lib:enablePattern(posid)
  local pat = self.db:getPattern(posid)
end

-- seq.Song(...)
function lib.new()
  local self = {
    -- enabled patterns by posid
    active_patterns = {},
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
  assert(db, 'Cannot save pattern without database')
  db:setSong(self)
end

function lib:delete()
  local db = self.db
  assert(db, 'Cannot delete pattern without database')
  db:deleteSong(self)
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


