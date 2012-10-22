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
function lib.new()
  local self = {
  }
  return setmetatable(self, lib)
end



