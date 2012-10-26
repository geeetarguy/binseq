--[[------------------------------------------------------

  seq.LPresetView
  ---------------

  This view shows the following elements:

  ( usual global commands )
  [ Green = playing, Red = playing + auto-save, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'seq.LPresetView', name = 'PresetView'}
lib.__index         = lib
seq.LPresetView     = lib
-- Last column operation to function
local col_button    = {}
-- Map top buttons
local top_button    = {}
local private       = {}
local m             = seq.LMainView.common

--=============================================== CONSTANTS
-- Last column button parameter selection
local PARAMS      = m.PARAMS

local PART_STATE = {
  'Off',        -- no preset
  'Amber',      -- has preset
  'Green',      -- loaded
  'Red',        -- loaded with auto-save
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
  local curr  = seq.partition.posid
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

function private:pressGrid(row, col)
  local posid = gridToPosid(row, col, self.page)
  -- Change partition (creates new if needed)
  self.seq:selectPartition(posid)
  self.pad:button(row, col):setState(PART_STATE[4])
end
