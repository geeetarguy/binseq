--[[------------------------------------------------------

  binseq.Pattern
  --------------

  A Pattern contains:
    * list of events
    * global settings
      => note (tuning), velocity, length, position, loop (truncate evt loop)

  The pattern responds to
    * enable (adds itself to the sequencer)
    * disable (removes itself from the sequencer)
    * setSequencer (when assigned to a different sequencer)


--]]------------------------------------------------------
local lib = {type = 'binseq.Pattern'}
lib.__index      = lib
binseq.Pattern    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- binseq.Pattern(...)
function lib.new(def)
  local self = {
    -- Find event by event posid
    events = {},
    chords = {_len = 0},
    -- List of events whose purpose is to change currently playing chord.
    -- The chord changer just increases the current chord_index.
    chord_changers = {},
    -- Tuning (set in global pseudo event)
    tuning = 12,
    -- Move start positions
    position = 0,
    -- Restrict loop size (0 = no restriction)
    loop   = 0,
    -- Add to velocity
    velocity = 0,
  }
  -- Global settings that alter playback of all events
  private.makeGlobal(self)

  setmetatable(self, lib)
  if def then
    self:set(def)
  end
  return self
end

function lib:set(def)
  for k, v in pairs(def) do
    self[k] = v
  end

  private.copyInGlobal(self)

  if self.db then
    self:save()
  end
end

-- aseq can be nil
function lib:setSequencer(aseq)
  if self.seq == aseq then return end
  self.seq = aseq
  -- Schedule pattern events
  for _, e in pairs(self.events) do
    e:setSequencer(aseq)
  end

  if aseq then
    self:set {sequencer_id = aseq.id}
  else
    self.sequencer_id = nil
    self:save()
  end
end

function lib:save()
  -- Write event in database
  local db = self.db
  assert(db, 'Cannot save pattern without database')
  db:setPattern(self)
end

function lib:loadEvents()
  if not self.loaded then
    -- load events
    local events = self.events

    for e in self.db:getEvents(self.id) do
      events[e.posid] = e
      e:setPattern(self)
    end
    self.loaded = true
  end
end

function lib:getOrCreateEvent(posid)
  local e = self.events[posid]
  if not e then
    e = self.db:getOrCreateEvent(posid, self.id)
    self.events[posid] = e
    e:setPattern(self)
    if self.seq then
      -- Schedule event
      e:setSequencer(self.seq)
    end
  end
  return e
end

-- Return chord to play at time t (computed by using the list
-- of chord changes).
function lib:chordIndex(t)
  local len = self.chords._len
  if len == 0 then
    return nil
  end

  -- count = sum(number of changes until now for each changer)
  local count = 0
  for _, c in ipairs(self.chord_changers) do
    local l = c.loop
    local p = c.position
    local c_count = math.floor(t / l) 
    -- |---- p --|---- p --|--x
    -- idx =
    -- 1     2   2     3   3  3
    -- c_count = 
    -- 0     0   1     1   2  2
    local pos = t - c_count * l
    if pos >= p and p > 0 then
      c_count = c_count + 1
    end
    -- 0     1   1     2   2  2
    count = count + c_count
  end
  return 1 + count % len
end

function lib:chord(t)
  local c = self.chords[self:chordIndex(t)]
  if not c or c.mute == 1 then
    -- Muted chord is not played
    return nil
  else
    return c
  end
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

function private.setGlobal(e, def)
  local self = e.pat
  local need_schedule = false
  for key, value in pairs(def) do
    e[key] = value
    if key == 'note' then
      self.tuning = value
    elseif key == 'loop' then
      need_schedule = true
      self.loop = value
    elseif key == 'position' then
      need_schedule = true
      self.position = value
    elseif key == 'velocity' then
      self.velocity = value
    end
  end
  -- Save
  self:save()
  -- Reschedule events
  if need_schedule then
    local seq = self.seq
    if seq then
      for _, e in pairs(self.events) do
        seq:reSchedule(e)
      end
    end
  end
end

function private:copyInGlobal()
  local glo = self.global
  glo.note     = self.tuning
  glo.loop     = self.loop
  glo.position = self.position
  glo.velocity = self.velocity
end

function private:makeGlobal()
  local glo = binseq.Event()
  glo.pat = self
  glo.set = private.setGlobal
  glo.posid = 0
  glo.mute  = 0
  glo.velocity = 0
  glo.position = 0
  glo.loop     = 0
  glo.length   = 0
  self.global = glo
end
