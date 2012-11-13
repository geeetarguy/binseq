--[[------------------------------------------------------

  seq.Sequencer
  -------------

  A Sequencer contains:
    * list of active patterns
    * global settings
      => note, velocity, length, position, loop
      => channel, mute, pattern mode (single, multiple, latch)

  The sequencer responds to
    * play(t): trigger events for all active patterns
      (one list contains all future events for active
       patterns)
    * addPattern(pattern)
    * removePattern(posid)
    * allOff: called to mute all current ON notes.
    * move(t): must be called to move song position.

--]]------------------------------------------------------
local lib = {type = 'seq.Sequencer'}
lib.__index      = lib
seq.Sequencer    = lib
local private    = {}

--=============================================== CONSTANTS

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Sequencer(...)
function lib.new(def)
  local self = {
    t    = 0,
    -- Playback list
    list = {},
    -- Active patterns by posid
    patterns = {},
    -- Global alterations
    note     = 0,
    velocity = 0,
    length   = 0,
    position = 0,
    loop     = 0,
  }
  setmetatable(self, lib)
  if def then
    self:set(def)
  end
  
  self.destroy = lk.Finalizer(function()
    self:allOff()
  end)

  return self
end

function lib:set(def)
  for k, v in pairs(def) do
    if k == 'loop' then
      if v > 0 then
        self.loop_v = v
      else
        self.loop_v = nil
      end
    end
    self[k] = v
  end

  if self.db then
    self:save()
  end
end

function lib:save()
  -- Write sequencer in database
  local db = self.db
  assert(db, 'Cannot save sequencer without database')
  db:setSequencer(self)
end

function lib:delete()
  local db = self.db
  assert(db, 'Cannot delete sequencer without database')
  db:deleteSequencer(self)
  self.deleted = true
end

function lib:enablePattern(posid)
  local pat = self:loadPattern(posid)
  pat:setSequencer(self)
end

function lib:disablePattern(posid)
  local pat = self.patterns[posid]
  if pat then
    pat:setSequencer(nil)
  end
end

function lib:loadPatterns()
  for posid in self.db:getActivePatternPosids(self.id) do
    self:loadPattern(posid)
  end
end

function lib:loadPattern(posid)
  local pat = self.song:getOrCreatePattern(posid)
  self.patterns[posid] = pat
  pat:setSequencer(self)
  return pat
end

function lib:allOff()
  local e = self.list.next
  self.list.next = nil
  while e do
    if e.off_t then
      self:trigger(e, true)
    end
    e = e.next
  end
end

-- Change song position.
function lib:move(t)
  self.t  = t
  -- Clear list
  self.list = {}
  local list = self.list
  local Gs = self.position
  local Gm = self.loop_v

  -- schedule all active patterns
  for _, pat in pairs(self.patterns) do
    for _, e in pairs(pat.events) do
      e:nextTrigger(t, Gs, Gm)
      if e.t then
        private.insertInList(list, e)
      end
    end
  end
end

function lib:schedule(e, not_now)
  e:nextTrigger(self.t, self.position, self.loop_v, not_now)
  if e.t then
    private.insertInList(self.list, e)
  end
end

function lib:trigger(e, skip_schedule)
  -- 1. Trigger event
  if e.mute == 0 or e.off_t then
    local f = self.playback
    if f then
      f(self, e)
    end
  end
  -- Keep last trigger time to reschedule event on edit/create.
  self.t = e.t
  -- 2. Reschedule
  if not skip_schedule then
    self:schedule(e, true)
  end
end

function lib:removeEvent(e)
  -- Remove from previous list
  local p = e.prev
  local n = e.next

  if p then
    p.next = n
    e.prev = nil
  end

  if n then
    n.prev = p
    e.next = nil
  end
end

function private.insertInList(list, e)
  -- Remove from previous list
  local p = e.prev
  local n = e.next
  local t = e.t

  if p then
    p.next = n
    e.prev = nil
  end
  if n then
    n.prev = p
    e.next = nil
  end

  if e.mute == 0 then
    -- not muted
    -- insert sorted
    local l = list
    while true do
      if l.t and t < l.t then
        -- insert before
        local b = l.prev
        l.prev = e
        e.next = l
        if b then
          b.next = e
          e.prev = b
        end
        break
      end

      -- Any next item ?
      local n = l.next
      if not n then
        -- end of list reached
        l.next = e
        e.prev = l
        break
      else
        l = n
      end
    end
  end
end
