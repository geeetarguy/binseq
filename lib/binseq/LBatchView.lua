--[[------------------------------------------------------

  binseq.LBatchView
  -----------------

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
local lib = {type = 'binseq.LBatchView', name = 'Batch'}
lib.__index         = lib
binseq.LBatchView      = lib
-- Last column operation to function
local col_press     = {}
-- Map top buttons
local top_button    = {}
local private       = {}
local m             = binseq.LMainView.common

private.loadParam  = m.loadParam
private.setParam   = m.setParam
private.pressMulti = m.pressMulti
private.editMulti  = m.editMulti

--=============================================== CONSTANTS
-- Last column button parameter selection
local PARAMS      = m.PARAMS
local BIT_STATE   = m.BIT_STATE
local PLURALIZE   = m.PLURALIZE
local KEY_TO_ROW  = m.KEY_TO_ROW

local rowToPosid = binseq.Event.rowToPosid
local posidToRow = binseq.Event.posidToRow


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

-- binseq.LBatchView(...)
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
function lib:display(key)
  self.list   = nil
  self.list_e = nil
  local key = key or self.key
  local page = self.page
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
function lib:setEventState(e, off_t)
  local pat = e.pat
  if pat ~= self.song.edit_pattern then return end

  local key = self.key

  local btn, b
  if e == self.list_e then
    -- Event edited in value list
    local idx = e.etype == 'chord' and 1 or e.index[key] or 1
    btn = self.pad:button(idx, 1)
    b   = self.bits[key][idx][1] + 1
  elseif self.list_e then
    -- not visible
    return
  else
    local posid = e.posid
    local row = self.row_by_id[posid]
    -- Bit value for this element
    if not row then return end
    local idx = e.etype == 'chord' and 1 or e.index[key]
    if idx then
      b = 1
      btn = self.pad:button(row, idx)
    else
      b   = self.bits[key][row][1] + 1
      btn = self.pad:button(row, 1)
    end
  end

  if e.mute == 1 then
    b = b + 3
  end
  if off_t or e.off_t then
    -- Note is on
    btn:setState(NOTE_ON_STATE[b])
  else
    -- Note is off
    btn:setState(NOTE_OFF_STATE[b])
  end

  if type(e.off_n) == 'table' then
    self:setEventState(e.off_n.chord, e.off_t)
  end
end

-- Used to reload event data on mute change
function lib:editEvent(e)
  local key = self.key
  local row = posidToRow(e.posid, self.page)

  if row then
    self.row_by_id[e.posid] = row
    self.events[row] = e
    private.loadParam(self, key, e, e[key], BIT_STATE, row)
  end
end
lib.eventChanged = lib.editEvent

function lib:press(row, col)
  if row == 0 then
    f = top_button[col]
  elseif col == 9 then
    f = col_press[row]
  else
    f = private.pressGrid
  end
  if f then
    f(self, row, col)
  else
    -- default lseq handling
    self.lseq:press(row, col)
  end
end

for i, key in ipairs(PARAMS) do
  if key ~= '' then
    col_press[i] = function(self, row, col)
      if key == self.key and self.list_e then
        private.toggleMulti(self, 0, 5)
      else
        self.lseq:loadView('Batch', key)
      end
    end
  end
end


function private:toggleMulti(row, col)
  if self.list_e then
    self.list_e = nil
    self.list = nil
    local last_key = self.last_key
    local key = self.key
    self.key = nil
    self.lseq:loadView('Batch', key)
    self.last_key = last_key
  elseif self.edit_multi then
    self.edit_multi = nil
    self.pad:button(0, col):setState('Off')
  else
    self.edit_multi = true
    self.pad:button(0, col):setState('Amber')
  end
end
top_button[5] = private.toggleMulti

function private:pressGrid(row, col)
  local key  = self.key
  local song = self.song
  if self.list_e then
    private.pressMulti(self, row, col, key)
  else
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

    if self.edit_multi or e[PLURALIZE[self.key]] then
      self.edit_multi = nil
      private.editMulti(self, e)
      self.pad:button(0, 5):setState('Green')
    else
      if col == 1 then
        private.setParam(self, self.key, row, col, e, e.off_t and NOTE_ON_STATE or NOTE_OFF_STATE)
      else
        private.setParam(self, self.key, row, col, e, BIT_STATE)
      end
    end
    self.last_e = e
  end
end
