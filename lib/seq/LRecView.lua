--[[------------------------------------------------------

  seq.LRecView
  ------------

  This view shows the following elements:

  ( usual global commands )
  [ Green = playing, Red = playing + auto-save, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'seq.LRecView', name = 'Rec'}
lib.__index         = lib
seq.LRecView        = lib
-- Last column operation to function
local col_button    = {}
-- Map top buttons
local top_button    = {}
local private       = {}
local m             = seq.LMainView.common
local gridToPosid   = seq.Event.gridToPosid 
local posidToGrid   = seq.Event.posidToGrid

--=============================================== CONSTANTS
-- Last column button parameter selection
local PARAMS      = m.PARAMS
local EVENT_LIST  = m.EVENT_LIST

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LRecView(...)
function lib.new(lseq, seq)
  local self = {
    lseq = lseq,
    pad = lseq.pad,
    seq = seq,
    -- default pagination
    page = 0,
    -- events to record (order as added)
    rec_list = {size = 0},
    -- events to record by posid
    rec_events = {},
    -- what to record
    keys = {},
    -- recording index
    idx = 1,
  }

  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display()
  local pad = self.pad
  local seq = self.seq
  local events = self.seq.partition.events
  local page = self.page
  local rec_events = self.rec_events
  local rec_list = self.rec_list

  -- Clear
  pad:prepare()
  pad:clear()
  -- Display events
  -- Turn on rec button
  pad:button(0, 4):setState('Red')

  for row=1,8 do
    for col=1,8 do
      local posid = gridToPosid(row, col, page)
      local e = events[posid]
      if e then
        if rec_events[e.posid] then
          if e.deleted then
            -- do not show
            private.removeFromList(self, rec_events, rec_list, e)
          end
        end
        self:setEventState(e)
      end
    end
  end

  -- keys
  for i, key in ipairs(PARAMS) do
    if self.keys[key] then
      self.pad:button(i, 9):setState('Red')
    else
      self.pad:button(i, 9):setState('Off')
    end
  end
  self.lseq:showSeqButtons()
  pad:commit()
end

function lib:setEventState(e)
  local posid = e.posid
  local row, col = posidToGrid(posid, self.page, 8)
  if not row then
    return
  end
  local btn = self.pad:button(row, col)
  local b = 2
  if e.off_t then
    -- NoteOn
    b = 5
  else
    b = 2
  end

  if self.rec_events[e.posid] then
    if self.rec_list[self.idx] == e then
      btn:setState('Red')
      return
    else
      b = b + 1
    end
  end

  btn:setState(EVENT_LIST[b])
end


function lib:press(row, col)
  local f
  if row == 0 then
    f = top_button[col]
  elseif col == 9 then
    f = col_button[row]
  else
    -- press on grid
    f = private.pressGrid
  end
  if f then
    f(self, row, col)
  else
    self.lseq:press(row, col)
  end
end

function private:loadMain(row, col)
  self.lseq:loadView('Main')
end
top_button[8] = private.loadMain

-- Last column buttons
function private:batchButton(row, col)
  local key = PARAMS[row]
  if self.keys[key] then
    self.keys[key] = nil
    self.pad:button(row, col):setState('Off')
  else
    self.keys[key] = true
    self.pad:button(row, col):setState('Red')
  end
end
for i, key in ipairs(PARAMS) do
  if key ~= '' then
    col_button[i] = private.batchButton
  end
end

function private:loadPrevious(row, col)
  local last = self.lseq.last_name
  if last then
    self.lseq:loadView(last)
  else
    local akey
    for key, _ in pairs(self.keys) do
      akey = key
      break
    end
    self.lseq:loadView('Batch', akey)
  end
end
top_button[4] = private.loadPrevious

function private:pressGrid(row, col)
  -- toggle recording state
  local pad = self.pad
  local seq = self.seq
  local rec_events = self.rec_events
  local rec_list = self.rec_list

  local posid = gridToPosid(row, col, self.page)

  local e = seq.partition.events[posid]
  if rec_events[posid] then
    -- remove
    private.removeFromList(self, rec_events, rec_list, e)
  else
    -- add to list
    table.insert(rec_list, e)
    rec_list.size = rec_list.size + 1
    rec_events[posid] = e
  end
  self:setEventState(e)
end

function private:removeFromList(rec_events, rec_list, e)
  rec_events[e.posid] = nil
  for i,le in ipairs(rec_list) do
    if le == e then
      table.remove(rec_list, i)
      rec_list.size = rec_list.size - 1
      if i == self.idx then
        if rec_list[i] then
          self:setEventState(rec_list[i])
        else
          self.idx = math.max(1, self.idx - 1)
        end
      end
      break
    end
  end
end

function lib:record(msg)
  if msg.type ~= 'NoteOn' then
    return
  end

  local list = self.rec_list
  local idx = self.idx
  local e = list[idx]
  local view = self.lseq.view

  idx = 1 + (idx % list.size)
  self.idx = idx

  if e then
    local change = {}
    for key, _ in pairs(self.keys) do
      if key == 'note' then
        change[key] = msg.note
      end
    end
    self.seq:setEvent(e.posid, change)
    if view == self then
      self:setEventState(e)
    elseif view then
      local f = view.eventChanged
      if f then
        f(view, e)
      end
    end
  end

  local ne = list[idx]
  if ne and view == self then
    self:setEventState(ne)
  end
end
