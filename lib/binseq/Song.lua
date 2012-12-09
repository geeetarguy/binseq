--[[------------------------------------------------------

  binseq.Song
  -----------

  A song contains
    * 64 patterns
    * 1 to 8 sequencers

  The song responds to
    * play(t): trigger events for all sequencers
    * move(t): change song position
    * enablePattern(posid): turn pattern On 
    * disablePattern(posid): turn pattern Off
    
--]]------------------------------------------------------
local lib = {type = 'binseq.Song'}
lib.__index      = lib
binseq.Song    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- binseq.Song(...)
function lib.new(def_or_db_path, song_id, name)
  if song_id then
    local db_path = def_or_db_path
    local db = binseq.PresetDb(db_path)
    return db:getOrCreateSong(song_id, name)
  end
  local def = def_or_db_path
    
  local self = def or {}
  -- Find pattern by posid
  self.patterns = {}

  -- Find sequencers by posid
  self.sequencers = {}
  -- Sequencers list
  self.sequencers_list = {}

  setmetatable(self, lib)

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
      sequencers[s.posid] = s
      s.song = self
      s:loadPatterns()
      table.insert(list, s)
    end
  end

  return self
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
    p.song = self
    pat[posid] = p
  end
  p:loadEvents()
  return p
end

function lib:set(def)
  for k,v in pairs(def) do
    self[k] = v
  end
  if self.db then
    self:save()
  end
end

function lib:save()
  -- Write song in database
  local db = self.db
  assert(db, 'Cannot save song without database')
  db:setSong(self)
end

function lib:dump()
  local patterns = {}
  for posid, pat in pairs(self.patterns) do
    patterns[posid] = pat:dump()
  end

  return {
    type   = self.type,
    data   = {
      name = self.name,
    },
    patterns = patterns,
  }
end

function lib:copy(dump)
  self:set(dump.data)
  for posid, d in pairs(dump.patterns) do
    local pat = self:getOrCreatePattern(posid)
    pat:copy(d)
  end
end

function lib:delete()
  self:allOff()
  local db = self.db
  assert(db, 'Cannot delete song without database')
  db:deleteSong(self)
  self.deleted = true
end

-- TODO: is this used ?
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

function lib:allOff()
  for _, s in pairs(self.sequencers) do
    s:allOff()
  end
end

--================================================== Used for testing
local gridToPosid = binseq.Event.gridToPosid
function lib.mock()
  local db = binseq.PresetDb ':memory:'
  local song = db:getOrCreateSong(1, 'hello')
  for row = 1,6 do
    for col = 1,8 do
      song:getOrCreatePattern(gridToPosid(row, col, 0))
    end
  end

  for _, pat_pos in ipairs {12, 15, 17, 1} do
    -- Set 4 patterns with 48 events each
    local pat = song:getOrCreatePattern(pat_pos)
    for row = 1,6 do
      for col = 1,8 do
        local posid = gridToPosid(row, col, 0)
        local e = pat:getOrCreateEvent(posid)
        -- One event on three is not muted
        if posid % 3 == 0 then
          e:set { mute = 0 }
        end
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
  -- Return a fresh copy like if it was queried from db
  return db:getSong(song.id)
end

