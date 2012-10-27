--[[------------------------------------------------------

  seq.LSeq
  --------

  Controller between the Launchpad and the sequencer.

--]]------------------------------------------------------
local lib = {type = 'seq.LSeq'}
lib.__index         = lib
seq.LSeq            = lib
local private       = {}
local top_button    = {}
local col_button    = {}
local m             = seq.LMainView.common
local PARAMS        = m.PARAMS

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LSeq(...)
function lib.new(sequencer, db_path)
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

function lib:loadView(name, ...)
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
  self.pad:loadView(view, ...)
end

-- Last column buttons
function private:batchButton(row, col)
  local key = PARAMS[row]
  self:loadView('Batch', key)
end
for i, key in ipairs(PARAMS) do
  if key ~= '' then
    col_button[i] = private.batchButton
  end
end

function private:presetButton(row, col)
  self:loadView('Preset')
end
top_button[6] = private.presetButton

-- Default actions when not implemented in view.
function lib:press(row, col)
  print('LSeq', row, col)
  local f
  if row == 0 then
    f = top_button[col]
  elseif col == 9 then
    f = col_button[row]
  end
  if f then
    f(self, row, col)
  end
end

-- Default actions when not implemented in view.
function lib:release(row, col)
end
