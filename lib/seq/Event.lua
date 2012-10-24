--[[------------------------------------------------------

  seq.Event
  ---------

  A partition is made of many events. An event contains
  the following information:

    * type (note, ctrl, etc). Only notes for the moment.
    * position (position in partition in midi clock values)
    * note (note value in midi)
    * loop (loop length for this event)
    * length (note duration)
    * velocity (note velocity)

--]]------------------------------------------------------
local lib = {type = 'seq.Event'}
lib.__index      = lib
seq.Event    = lib
local private    = {}
local COPY_KEYS = {'position', 'loop', 'note', 'length', 'velocity'}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Event(...)
function lib.new(def)
  local self = {
    mute     = true,
    position = 0,
    loop     = 24,
    note     = 0,
    length   = 6,
    velocity = 48,
  }
  setmetatable(self, lib)
  if def then
    self:set(def)
  end
  return self
end

-- Returns true if the event timing info changed (needs reschedule).
function lib:set(def)
  local need_schedule = false
  if def.id then
    -- copy
    need_schedule = true
    for _, key in ipairs(COPY_KEYS) do
      if key == 'length' then
        if self.off_t then
          self.off_t = self.off_t - self.length + value
        end
      end
      self[key] = def[key]
    end
  else
    for key, value in pairs(def) do
      if key == 'length' then
        if self.off_t then
          self.off_t = self.off_t - self.length + value
        end
        need_schedule = true
      elseif not need_schedule and key == 'position' or key == 'loop' then
        need_schedule = true
      end
      self[key] = value
    end
  end

  return need_schedule
end

-- 0      Gs             Ep       Ep (ignored)
-- |-------|-------------x--|-----x
-- |-------|---- m ---------|
-- |-------|- tl -|- te -|        normal trigger
-- |-------|--- p -------|
--
-- |-------|---- tl -------|------------------ te --|      wrap around on next loop
-- |-------|--- p -------|
-- t = time in midi clock since start of song.
function lib:nextTrigger(t, Gs, Gm, not_now)
  local m = Gm or self.loop
  local p = self.position - Gs
  -- off_t is off time (set during NoteOn trigger)
  local off_t = self.off_t
  if t == self.allow_now_t then
    not_now = false
    self.allow_now_t = nil
  end

  if p < 0 or p >= m then
    -- Out of current loop region: ignore or trigger NoteOff
    self.t = off_t
    return off_t
  end
  
  local tl = t % m
  local te = p - tl
  if te < 0 or (not_now and te == 0) then
    -- Wrap around loop
    te = te + m
  end
  
  -- Return absolute next trigger
  local nt = t + te
  if off_t and off_t < nt then
    self.t = off_t
    return off_t
  else
    -- If off_t == nt, we should not take not_now in consideration on next
    -- run so that the next loop triggers the same nt.
    if off_t == nt then
      self.allow_now_t = nt
    end
    self.t = nt
    return nt
  end
end

-- Return midi event to trigger
function lib:trigger(chan)
  local chan = chan or 1
  if self.off_t then
    -- NoteOff
    self.off_t = nil
    return chan - 1 + 0x80, self.off_n, self.velocity
  else
    -- NoteOn
    self.off_t = self.t + self.length
    -- Make sure the NoteOff message uses the same note value
    self.off_n = self.note
    return chan - 1 + 0x90, self.note, self.velocity
  end
end
