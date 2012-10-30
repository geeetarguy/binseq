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
  local pat = self.song:getOrCreatePattern(posid)
  self.patterns[posid] = pat
  -- Schedule pattern events
  for _, e in pairs(pat.events) do
    e:setSequencer(self)
  end
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

--[[

function lib:addPattern(pat)
  local pat = self.db:getPattern(posid)
function lib:selectPattern(posid)
  private.allOff(self)
  if not posid then
    -- turn off
    self.pattern = nil
    self.list.next = nil
    return
  end

  local part = self.db:getPattern(posid, self.id)
  if not part then
    part = self.db:createPattern(posid, self.id)
  end
  self.pattern = part
  self.global_loop  = part.loop > 0 and part.loop
  self.global_start = part.position
  self:scheduleAll()
end

function lib:eventCount()
  return #self.pattern.events_list
end

function lib:getEvent(posid)
  return self.pattern.events[posid]
end

-- The global loop setting overrides individual event loops.
function lib:setGlobalLoop(m)
  self.pattern.global_loop = m
  self.global_loop = m
  self:scheduleAll()
end

-- The global start offset.
function lib:setGlobalStart(s)
  self.pattern.position = s
  self.global_start = s
  self:scheduleAll()
end

-- Return a sorted linked list of active events given the current global
-- start and global loop settings.
function lib:scheduleAll(tc)
  local tc = tc or self.t
  -- Clear list
  self.list = {}
  local list = self.list

  local Gs = self.global_start
  local Gm = self.global_loop
  for _, e in ipairs(self.pattern.events) do
    -- This sets e.t
    e:nextTrigger(tc, Gs, Gm)
    private.insertInList(list, e)
    if seq_debug then
      local l = list.next
      while l do
        l = l.next
      end
    end
  end

  return list
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

-- Start playback
function lib:play(bpm)
  if self.thread then
    -- do nothing
  else
    -- Start playback thread
    -- Current time = now
    -- Convert bpm in ms/tick
    -- one beat = 24 ticks
    -- = one minute / (bpm * 24) = 60000 / (bpm * 24)
    self.ms_per_tick = 60000 / bpm / 24
    -- song position
    self.t = 0
    -- sequencer start in ms
    self.start_ms = now()
    self.playing = true
    self:scheduleAll()
    private.startThread(self)
  end
end

function private:startThread()
  local list = self.list
  if list.next then
    self.thread = lk.Thread(function(thread)
      while self.playing do
        local e = list.next
        if e then
          -- event play time in ms relative to 'now'
          local dt = self.start_ms - now() + e.t * self.ms_per_tick
          if dt > 0 then
            sleep(dt)
          else
            self:trigger(e)
          end
        else
          -- no event to play. stop.
          self.thread = nil
          return
        end
      end
    end)
  else
    -- no event to play in current loop
    self.thread = nil
  end
end

function lib:schedule(e, not_now)
  e:nextTrigger(self.t, self.global_start, self.global_loop, not_now)
  private.insertInList(self.list, e)
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

  if t then
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
--]]
