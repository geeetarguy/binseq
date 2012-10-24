--[[------------------------------------------------------

  seq.Sequencer
  -------------

  MIDI Sequencer.

--]]------------------------------------------------------
local lib = {type = 'seq.Sequencer'}
lib.__index      = lib
seq.Sequencer    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Sequencer(...)
function lib.new()
  local self = {
    partitions = {seq.Partition()},
    t = 0,
    list = {},
    global_loop_value = 24,
  }
  setmetatable(self, lib)
  self:selectPartition(1)
  return self
end

function lib:selectPartition(idx)
  local part = self.partitions[idx]
  self.partition = part
  self.global_loop = part.global_loop
  self.global_start = part.global_start
end

function lib:eventCount()
  return self.partition.events.count
end

function lib:getEvent(id)
  return self.partition.events[id]
end

function lib:setEvent(id, def)
  local e = self:getEvent(id)
  local new_event = false
  if not e then
    new_event = true
    e = seq.Event()
    e.id = id
    self.partition.events[id] = e
  end
  if e:set(def) or new_event then
    private.schedule(self, e)
  end
  return e
end

-- The global loop setting overrides individual event loops.
function lib:setGlobalLoop(m)
  self.partition.global_loop = m
  self.global_loop = m
  self:buildActiveList(self.t)
end

-- The global start offset.
function lib:setGlobalStart(s)
  self.partition.global_start = s
  self.global_start = s
  self:buildActiveList(self.t)
end

-- Return a sorted linked list of active events given the current global
-- start and global loop settings.
function lib:buildActiveList(tc)
  local list = self.list
  -- Clear list (we do not replace list because it can be stored in upvalues)
  local n = list.next
  if n then
    n.prev = nil
  end
  list.next = nil

  local Gs = self.global_start
  local Gm = self.global_loop
  for _, e in ipairs(self.partition.events) do
    -- This sets e.t
    e:nextTrigger(tc, Gs, Gm)
    private.insertInList(self, list, e)
    if seq_debug then
      local l = list.next
      while l do
        l = l.next
      end
    end
  end

  return list
end

function lib:trigger(e)
  -- 1. Trigger event
  if not e.mute or e.off_t then
    local f = self.playback
    if f then
      f(self, e)
    end
  end
  -- Keep last trigger time to reschedule event on edit/create.
  self.t = e.t
  -- 2. Reschedule
  private.schedule(self, e, true)
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
    self:buildActiveList()
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

function private:schedule(e, not_now)
  e:nextTrigger(self.t, self.global_start, self.global_loop, not_now)
  private.insertInList(self, self.list, e)
end

function private.insertInList(self, list, e)
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

    if self.playing and not self.thread then
      private.startThread(self)
    end
  end
end
