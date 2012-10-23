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
  if not e then
    e = seq.Event()
    e.id = id
    self.partition.events[id] = e
  end
  e:set(def)
  private.schedule(self, e)
  return e
end

-- The global loop setting overrides individual event loops.
function lib:setGlobalLoop(m)
  self.partition.global_loop = m
  self.global_loop = m
end

-- The global start offset.
function lib:setGlobalStart(s)
  self.partition.global_start = s
  self.global_start = s
end

-- Return a sorted linked list of active events given the current global
-- start and global loop settings.
function lib:buildActiveList(tc)
  local list = {}
  self.list = list
  local Gs = self.global_start
  local Gm = self.global_loop
  for _, e in ipairs(self.partition.events) do
    local t = e:nextTrigger(tc, Gs, Gm)
    private.insertInList(list, e, t)
  end

  return list
end

function lib:trigger(e)
  -- 1. Trigger event
  --  TODO
  -- Keep last trigger time to reschedule event on edit/create.
  self.t = e.t
  -- 2. Reschedule
  private.schedule(self, e, true)
end

function private:schedule(e, not_now)
  local t = e:nextTrigger(self.t, self.global_start, self.global_loop, not_now)
  private.insertInList(self.list, e, t)
end

function private.insertInList(list, e, t)
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

  e.t = t

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
      local n = l.next
      if not n then
        -- add at end
        l.next = e
        e.prev = l
        break
      else
        l = n
      end
    end
  end
end
