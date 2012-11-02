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
local lib = {type = 'seq.LBatchView', name = 'Batch'}
lib.__index         = lib
seq.LBatchView      = lib
-- Last column operation to function
local col_button    = {}
-- Map top buttons
local top_button    = {}
local private       = {}
local m             = seq.LMainView.common

private.loadParam = m.loadParam
private.setParam  = m.setParam

--=============================================== CONSTANTS
-- Last column button parameter selection
local PARAMS      = m.PARAMS
local BIT_STATE   = m.BIT_STATE
local KEY_TO_ROW  = {}
for i, key in ipairs(PARAMS) do
  if key ~= '' then
    KEY_TO_ROW[key] = i
  end
end
local rowToPosid = seq.Event.rowToPosid
local posidToRow = seq.Event.posidToRow

local NOTE_ON_STATE = {
  'Green',
  'Amber',
  'Red',
  -- mute states
  'LightRed',
  'LightRed',
  'LightRed',
  'Red' -- mute button
}

local NOTE_OFF_STATE = {
  'LightGreen',
  'LightAmber',
  'LightRed', -- ???
  -- mute states
  'LightRed',
  'LightRed',
  'LightRed',
  'Red' -- mute button
}

local PAGE_BITS = {
  8,
  4,
  2,
  1,
}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LBatchView(...)
function lib.new(lseq, song)
  local self = {
    lseq = lseq,
    pad = lseq.pad,
    song = song,
    key = 'note',
    -- Direct access to bit values (ex: bits[row][col])
    bits = {},
    -- Direct access to grid buttons
    btns = {},
    -- Edited events (independant of event.posid)
    events = {},
    -- Find event from posid
    row_by_id = {},
    -- Pagination
    page = 0,
  }
  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display(key, page)
  local key = key or self.key
  local page = page or self.page
  self.key = key
  self.last_key = nil
  local pad = self.pad
  local song = self.song
  local events = self.events
  -- Clear
  pad:prepare()
  pad:clear()

  -- Display events
  local row_by_id = {}
  self.row_by_id = row_by_id

  local part_events = song.edit_pattern.events
  for row=1,8 do
    local posid = rowToPosid(row, page)
    local e = part_events[posid]
    if e then
      private.loadParam(self, key, e, e[key], BIT_STATE, row)
      row_by_id[e.posid] = row
      events[row] = e
      self:setEventState(e)
    else
      events[row] = nil
    end
  end
  pad:button(KEY_TO_ROW[key], 9):setState('Amber')
  pad:commit()
end

-- mandatory function for view
function lib:setEventState(e)
  local pat = e.pattern
  if pat ~= self.song.edit_pattern then
    return
  end
  local posid = e.posid
  local row = self.row_by_id[posid]
  -- Bit value for this element
  if row then
    local b = self.bits[self.key][row][1] + 1
    local btn = self.pad:button(row, 1)
    if e.mute == 1 then
      b = b + 3
    end
    if e.off_t then
      -- Note is on
      btn:setState(NOTE_ON_STATE[b])
    else
      -- Note is off
      btn:setState(NOTE_OFF_STATE[b])
    end
  end
end

-- Used to reload event data on mute change
function lib:editEvent(e)
  local row = posidToRow(e.posid, self.page)

  if row then
    self.row_by_id[e.posid] = row
    self.events[row] = e
    private.loadParam(self, self.key, e, e[self.key], BIT_STATE, row)
  end
end
lib.eventChanged = lib.editEvent

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

function private:pressGrid(row, col)
  local song = self.song
  local e = self.events[row]
  if not e then
    -- Copy last event
    -- Id is current page
    local posid = rowToPosid(row, self.page)
    -- new
    e = song.edit_pattern:getOrCreateEvent(posid)
    if self.last_e then
      -- copy
      e:set(self.last_e)
    end
    if key ~= 'mute' then
      e:set {
        [self.key] = 0,
      }
    end
    -- Reload content
    self:editEvent(e)
  end
  if col == 1 then
    private.setParam(self, self.key, row, col, e, e.off_t and NOTE_ON_STATE or NOTE_OFF_STATE)
  else
    private.setParam(self, self.key, row, col, e, BIT_STATE)
  end
  self.last_e = e
end

