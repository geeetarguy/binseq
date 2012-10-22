--[[------------------------------------------------------

  seq.Partition
  -------------

  A partition contains events and partition settings (host
  reset, etc).

--]]------------------------------------------------------
local lib = {type = 'seq.Partition'}
lib.__index      = lib
seq.Partition    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Partition(...)
function lib.new()
  local self = {
    events = {},
  }
  return setmetatable(self, lib)
end

