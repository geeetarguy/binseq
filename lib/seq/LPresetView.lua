--[[------------------------------------------------------

  seq.LPresetView
  ---------------

  This view shows the following elements:

  ( usual global commands )
  [ Green = playing, Red = playing + auto-save, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'seq.LPresetView', name = 'Preset'}
lib.__index         = lib
seq.LPresetView     = lib
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

local PART_STATE = {
  'Off',        -- no preset
  'LightAmber', -- has preset
  'Green',      -- loaded
  'Green',      -- loaded with auto-save
  'Red',        -- ready to delete
}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LMainView(...)
function lib.new(lseq)
  local self = {
    lseq = lseq,
    pad = lseq.pad,
    seq = lseq.seq,
    -- default pagination
    page = 0,
    -- partitions by posid (only exist / does not exist)
    partitions = {},
  }

  -- load parts info
  local db = self.seq.db
  local partitions = self.partitions
  for row=1,8 do
    for col=1,8 do
      local posid = gridToPosid(row, col, self.page)
      partitions[posid] = db:hasPartition(posid)
    end
  end

  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display()
  local pad = self.pad
  local seq = self.seq
  local parts = self.partitions
  local curr = (seq.partition or {}).posid
  local page = self.page
  -- Clear
  pad:prepare()
  pad:clear()
  -- Display partitions
  -- Turn on global button
  pad:button(0, 6):setState('Green')

  for row=1,8 do
    for col=1,8 do
      local posid = gridToPosid(row, col, page)
      if parts[posid] then
        if posid == curr then
          pad:button(row, col):setState(PART_STATE[4])
        else
          pad:button(row, col):setState(PART_STATE[2])
        end
      end
    end
  end
  pad:commit()
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

function private:copyDelPart()
  local row, col = 0, 5
  if self.copy_on then
    self.copy_on = false
    self.del_on = true
    self.pad:button(row, col):setState('Red')
  elseif self.del_on then
    self.del_on = false
    self.pad:button(row, col):setState('Off')
  else
    -- enable copy
    self.copy_on = true
    self.pad:button(row, col):setState('Green')
  end
end
top_button[5] = private.copyDelPart

function private:pressGrid(row, col)
  local pad = self.pad
  local seq = self.seq
  local posid = gridToPosid(row, col, self.page)
  -- Unselect old
  local curr = (seq.partition or {}).posid
  if curr then
    local cr, cc = posidToGrid(curr, self.page)

    if cr then
      pad:button(cr, cc):setState(PART_STATE[2])
    end
  end

  if self.copy_on then
    if posid ~= seq.partition.posid then
      -- copy current partition to given location
      seq.db:copyPartition(seq.partition, posid)
    end
    self.copy_on = false
    pad:button(0, 5):setState('Off')
    pad:button(row, col):setState(PART_STATE[2])
    return
  elseif self.del_on == posid then
    -- delete
    local p = seq.db:getPartition(posid)
    p:delete()
    self.del_on = nil
    self.pad:button(0, 5):setState('Off')
    self.partitions[p.posid] = nil
    if p.posid ~= (self.seq.partition or {}).posid then
      pad:button(row, col):setState(PART_STATE[1])
    else
      pad:button(row, col):setState(PART_STATE[1])
      self.seq:selectPartition(1)
      self.partitions[1] = true
    end
    return
  elseif self.del_on then
    if seq.db:hasPartition(posid) then
      self.del_on = posid
      pad:button(row, col):setState(PART_STATE[5])
    end
    return
  end

  -- Change partition (creates new if needed)
  self.seq:selectPartition(posid)
  self.partitions[posid] = true
  pad:button(row, col):setState(PART_STATE[4])
end
