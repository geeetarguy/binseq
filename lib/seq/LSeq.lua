--[[------------------------------------------------------

  seq.LSeq
  --------

  Controller between the Launchpad and the sequencer.

--]]------------------------------------------------------
local lib = {type = 'seq.LSeq'}
lib.__index         = lib
seq.LSeq            = lib
local private       = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LSeq(...)
function lib.new(sequencer)
  local self = {
    pad = seq.Launchpad(),
    seq = sequencer,
    views = {},
  }
  local trigger = self.seq.trigger
  function sequencer.trigger(sequencer, e)
    trigger(sequencer, e)
    local view = self.view
    if view then
      view:setEventState(e)
    end
  end
  return setmetatable(self, lib)
end

function lib:loadView(name)
  local view = self.views[name]
  if not view then
    local t = seq['L'..name..'View']
    if t then
      view = t(self)
      self.views[name] = view
    else
      error('Could not find seq.L'..name..'View view')
    end
  end
  self.view = view
  self.pad:loadView(view)
end

-- Default actions when not implemented in view.
function lib:press(row, col)
end

-- Default actions when not implemented in view.
function lib:release(row, col)
end
