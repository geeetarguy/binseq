--[[------------------------------------------------------

  seq.Launchpad
  -------------

  The Launchpad is a view for the Sequencer and is
  connected to novation Launchpad via midi.

--]]------------------------------------------------------
local lib = {type = 'seq.Launchpad'}
lib.__index      = lib
seq.Launchpad    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Launchpad(...)
function lib.new()
  local self = {
  }
  return setmetatable(self, lib)
end


