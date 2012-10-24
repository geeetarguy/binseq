--[[------------------------------------------------------

  seq.LBatchView
  -------------

  This view shows the following elements:

  ( event navigation, usual global commands )
  [ Display 'key' parameter for event 1 in page       ]
  [ Display 'key' parameter for event 2 in page       ]
  [ "                                                 ]
  [ "                                                 ] (edit 'note')

  [ "                                                 ] (edit 'velocity')
  [ "                                                 ] (edit 'length')
  [ "                                                 ] (edit 'position')
  [ "                                                 ] (edit 'loop')

  Click on the current edit param moves back to Main view.

--]]------------------------------------------------------
local lib = {type = 'seq.LBatchView'}
lib.__index         = lib
seq.LBatchView      = lib
-- Last column operation to function
local col_button    = {}
-- Map top buttons
local top_button    = {}
local private       = {}
local m             = seq.LMainView.batch

private.loadParam = m.loadParam
private.setParam  = m.setParam

--=============================================== CONSTANTS
-- Last column button parameter selection
local PARAMS      = m.PARAMS
local KEY_TO_ROW  = {}
for i, key in ipairs(PARAMS) do
  if key ~= '' then
    KEY_TO_ROW[key] = i
  end
end

local BIT_STATE = {
  'Off',
  'Amber',
  'Green',
  'LightRed', -- mute
}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LBatchView(...)
function lib.new(lseq)
  local self = {
    lseq = lseq,
    pad = lseq.pad,
    seq = lseq.seq,
    -- Direct access to bit values (ex: bits[row][col])
    bits = {},
    -- Direct access to grid buttons
    btns = {},
    -- Edited events (independant of event.id)
    events = {},
    -- Find event from id
    row_by_id = {},
    -- Pagination
    page = 1,
  }
  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display(key)
  self.key = key
  local pad = self.pad
  local seq = self.seq
  -- Clear
  pad:clear()
  pad:prepare()
  -- Display events
  local row = 1
  local offset = (self.page-1) * 8
  local row_by_id = {}
  self.row_by_id = row_by_id
  for id, e in ipairs(seq.partition.events) do
    if offset > 0 then
      offset = offset - 1
    else
      if row > 8 then
        -- Only load first 8 elements in current page.
        break
      end
      private.loadParam(self, key, e, e[key], BIT_STATE, row)
      row_by_id[e.id] = row
      row = row + 1
    end
  end
  local row = KEY_TO_ROW[key]
  pad:button(row, 9):setState('Amber')
  pad:commit()
end

function lib:setEventState(e)
  local id = e.id
  local row = self.row_by_id[id]
  if row then
    local btn = self.pad:button(row, 1)
    if e.off_t then
      -- Note is on
      btn:setState('Green')
    else
      -- Note is off
      btn:setState('LightGreen')
    end
  end
end

function lib:press(row, col)
  if row == 0 then
    f = top_button[col]
  elseif col == 9 then
    f = col_button[row]
  else
    f = private.pressGrid
  end
  if f then
    f(self, row, col)
  else
    -- Default LSeq handling
    self.lseq:press(row, col)
  end
end

-- Last column buttons
function private:batchButton(row, col)
  local key = PARAMS[row]
  self.lseq:loadView('Batch', key)
end
for i, key in ipairs(PARAMS) do
  if key ~= '' then
    col_button[i] = private.batchButton
  end
end

function lib:release(row, col)
  -- ignore
end

-- Last column buttons
function private:batchButton(row, col)
  local key = PARAMS[row]
  if key == self.key then
    self.key = nil
    self.lseq:loadView('Main')
  else
    self.lseq:loadView('Batch', key)
  end
end
for i, key in ipairs(PARAMS) do
  if key ~= '' then
    col_button[i] = private.batchButton
  end
end
