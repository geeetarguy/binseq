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
    local f = view.setEventState
    if f then
      f(view, e)
    end
  end
  setmetatable(self, lib)
  self:loadView('Preset')
  return self
end

function lib:loadView(name, ...)
  if name ~= 'Preset' and not self.seq.partition then
    return -- refuse to leave preset page
  end

  if self.view then
    self.last_name = self.view.name
  end

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

function private:recButton(row, col)
  self:loadView('Rec')
end
top_button[4] = private.recButton

-- function private:recButton(row, col)
--   self:loadView('Rec')
-- end
-- top_button[8] = private.mainButton
-- Default actions when not implemented in view.
function lib:press(row, col)
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

function lib:record(msg)
  local rec = self.views['Rec']
  if rec then
    rec:record(msg)
  end
end
