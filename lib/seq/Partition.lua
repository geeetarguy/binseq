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
    events_list = {},
  }
  return setmetatable(self, lib)
end

function lib:addEvent(id, e)
  local events = self.events
  local list = self.events_list
  if events[id] then
    -- remove from list
    for i,e in ipairs(list) do
      if e.id == id then
        table.remove(list)
        break
      end
    end
  else
    events[id] = e
    table.insert(list, e)
  end
end
