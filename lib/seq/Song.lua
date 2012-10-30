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

-- seq.Song(...)
function lib.new(def)
  local self = def or {}
  -- Find pattern by posid
  self.patterns = {}

  -- Find sequencers by posid
  self.sequencers = {}
  -- Sequencers list
  self.sequencers_list = {}

  if self.db then
    -- load patterns
    local patterns = self.patterns

    for p in self.db:getPatterns(self.id) do
      p.song = self
      p:loadEvents()
      patterns[p.posid] = p
    end

    -- load sequencers
    local sequencers = self.sequencers
    local list = self.sequencers_list

    for s in self.db:getSequencers(self.id) do
      s.song = self
      s:loadPatterns()
      sequencers[s.posid] = s
      table.insert(list, s)
    end
  end

  return setmetatable(self, lib)
end

function lib:getOrCreateSequencer(posid)
  local s = self.sequencers[posid]
  if not s then
    s = self.db:getOrCreateSequencer(posid, self.id)
    s.song = self
    s:loadPatterns()
    self.sequencers[posid] = s
    table.insert(self.sequencers_list, s)
  end
  return s
end

-- Get a pattern (create if necessary) and preload all events.
function lib:getOrCreatePattern(posid)
  local pat = self.patterns
  local p = pat[posid]
  if not p then
    p = self.db:getOrCreatePattern(posid, self.id)
    pat[posid] = p
  end
  p:loadEvents()
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

--================================================== Used for testing
local gridToPosid = seq.Event.gridToPosid
function lib.mock()
  local db = seq.PresetDb(':memory')
  local song = db:createSong(1, 'hello')
  for row = 1,8 do
    for col = 1,8 do
      song:getOrCreatePattern(gridToPosid(row, col, 0))
    end
  end

  for _, pat_id in ipairs {12, 15, 17, 1} do
    -- Only fill 6 rows = 48 events
    local pat = song:getOrCreatePattern(pat_id)
    for row = 1,6 do
      for col = 1,8 do
        local posid = gridToPosid(row, col, 0)
        local e = pat:getOrCreateEvent(posid)
      end
    end
  end

  -- create 2 sequencers
  for _, col in ipairs {1, 3} do
    local seq = song:getOrCreateSequencer(gridToPosid(1, col, 0))
    -- activate some patterns
    seq:enablePattern(gridToPosid(1, col, 0))
    seq:enablePattern(gridToPosid(2, col+1, 0))
  end
  return song
end

