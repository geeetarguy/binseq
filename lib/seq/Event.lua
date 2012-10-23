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
    loop     = 96,
    note     = 0,
    velocity = 90,
  }
  setmetatable(self, lib)
  if def then
    self:set(def)
  end
  return self
end

function lib:set(def)
  for key, value in pairs(def) do
    self[key] = value
  end
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


