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
function lib.new(db_path)
  local db_path = db_path or os.getenv('HOME') .. '/Documents/seq.db'
  local self = {
    db  = seq.PresetDb(db_path),
    t = 0,
    list = {},
    global_loop_value = 24,
  }
  setmetatable(self, lib)
  
  self.destroy = lk.Finalizer(function()
    private.allOff(self)
  end)

  return self
end

function lib:selectPartition(posid)
  private.allOff(self)
  if not posid then
    -- turn off
    self.partition = nil
    self.list.next = nil
    return
  end

  local part = self.db:getPartition(posid)
  if not part then
    part = self.db:createPartition(posid)
  end
  self.partition = part
  self.global_loop  = part.loop > 0 and part.loop
  self.global_start = part.position
  self:buildActiveList()
end

function lib:eventCount()
  return #self.partition.events_list
end

function lib:getEvent(posid)
  return self.partition.events[posid]
end

function lib:setEvent(posid, def)
  local e = self:getEvent(posid)
  local new_event = false
  if not e then
    new_event = true
    e = self.partition:createEvent(posid)
  end
  if e:set(def) or new_event then
    private.schedule(self, e)
  end
  e:save()
  return e
end

-- The global loop setting overrides individual event loops.
function lib:setGlobalLoop(m)
  self.partition.global_loop = m
  self.global_loop = m
  self:buildActiveList()
end

-- The global start offset.
function lib:setGlobalStart(s)
  self.partition.position = s
  self.global_start = s
  self:buildActiveList()
end

-- Return a sorted linked list of active events given the current global
-- start and global loop settings.
function lib:buildActiveList(tc)
  local tc = tc or self.t
  -- Clear list
  self.list = {}
  local list = self.list

  local Gs = self.global_start
  local Gm = self.global_loop
  for _, e in ipairs(self.partition.events) do
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

function lib:trigger(e)
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

function private:allOff()
  local e = self.list.next
  self.list.next = nil
  while e do
    local ne = e.next
    e.prev = nil
    e.next = nil
    if e.off_t then
      self:trigger(e)
    end
    e = ne
  end
end

