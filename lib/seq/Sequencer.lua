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
  }
  setmetatable(self, lib)
  self:selectPartition(1)
  return self
end

function lib:selectPartition(idx)
  local part = self.partitions[idx]
  self.partition = part
end
