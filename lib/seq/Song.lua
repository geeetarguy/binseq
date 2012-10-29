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
function lib.new(def)
  local self = def or {}
  -- enabled patterns by posid
  self.active_patterns = {}

  -- Find pattern by posid
  self.patterns = {}

  if self.db then
    -- load patterns
    local patterns = self.patterns

    for p in self.db:getPatterns(self.id) do
      patterns[p.posid] = p
    end
  end

  return setmetatable(self, lib)
end

function lib:createPattern(posid)
  local e = self.db:createPattern(posid, self.id)
  self.patterns[posid] = e
  return e
end

-- Get a pattern and preload all events.
function lib:getPattern(posid)
  local pat = self.patterns
  local p = pat[posid]
  if not p then
    p = self.db:getPattern(posid, self.id)
    p:loadEvents()
    pat[posid] = p
  end
  return p
end

function lib:save()
  -- Write song in database
  local db = self.db
  assert(db, 'Cannot save song without database')
  db:setSong(self)
end

function lib:delete()
  local db = self.db
  assert(db, 'Cannot delete song without database')
  db:deleteSong(self)
  self.deleted = true
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


