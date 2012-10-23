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

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Event(...)
function lib.new(def)
  local self = {
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
  for key, value in pairs(def) do
    if not need_schedule and key == 'position' or key == 'loop' then
      need_schedule = true
    end
    self[key] = value
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
  if p < 0 or p >= m then
    -- Out of current loop region: ignore
    return nil
  end
  
  local tl = t % m
  local te = p - tl
  if te < 0 or (not_now and te == 0) then
    -- Wrap around loop
    te = te + m
  end
  -- Return absolute next trigger
  return t + te
end


