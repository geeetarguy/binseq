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
  local self = {
    -- Find event by event posid
    events = {}
  }

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

  if self.db then
    self:save()
  end
end

-- aseq can be nil
function lib:setSequencer(aseq)
  self.seq = aseq
  -- Schedule pattern events
  for _, e in pairs(self.events) do
    e:setSequencer(aseq)
  end
end

function lib:save()
  -- Write event in database
  local db = self.db
  assert(db, 'Cannot save pattern without database')
  db:setSequencer(self)
end

function lib:loadEvents()
  if not self.loaded then
    -- load events
    local events = self.events

    for e in self.db:getEvents(self.id) do
      events[e.posid] = e
    end
    self.loaded = true
  end
end

function lib:getOrCreateEvent(posid)
  local e = self.events[posid]
  if not e then
    e = self.db:getOrCreateEvent(posid, self.id)
    self.events[posid] = e
    if self.seq then
      -- Schedule event
      e:setSequencer(self.seq)
    end
  end
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

