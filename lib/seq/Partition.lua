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
    -- No global loop by default
    global_loop  = nil,
    -- Global offset is 0 by default
    global_start = 0,
    events = {
      count = 0,
    },
  }
  return setmetatable(self, lib)
end

