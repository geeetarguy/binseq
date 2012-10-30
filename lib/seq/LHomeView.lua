--[[------------------------------------------------------

  seq.LHomeView
  ---------------

  This view shows the following elements:

  ( usual global commands )
  [ Green = playing, Red = playing + auto-save, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'seq.LHomeView', name = 'Home'}
lib.__index         = lib
seq.LHomeView     = lib
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

local BIT_STATE = {
  'Off', 
  'Green',
  'Amber',
  'Red',
}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LHomeView(...)
function lib.new(lseq, song)
  local self = {
    lseq = lseq,
    pad  = lseq.pad,
    song = lseq.song,
    -- default pagination
    page = 0,
    patterns = {},
  }

  -- patterns by posid
  self.name_bits = private.nameToBits(song.name)

  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display()
  local pad  = self.pad
  local song = self.song
  local bits = self.name_bits
  local curr = (song.edit_pattern or {}).posid
  local page = self.page
  -- Clear
  pad:prepare()
  pad:clear()
  -- Display patterns
  -- Turn on 'pattern' button
  pad:button(0, 1):setState('Amber')

  for row=1,8 do
    for col=1,8 do
      local posid = gridToPosid(row, col, page)
      pad:button(row, col):setState(BIT_STATE[bits[posid]+1])
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
  local b = (self.name_bits[posid] + 1) % 4
  self.name_bits[posid] = b
  self.pad:button(row, col):setState(BIT_STATE[b+1])
  self.song:set {
    name = private.bitsToName(self.name_bits)
  }
  print(self.song.name)
end

function private.nameToBits(name)
  local bits = {}
  -- 64 bits, 4 states
  -- every 3 squares = 1 char 4*4*4
  -- ASCII 60 - 124
  for char_id=1,22 do
    local char = string.byte(name, char_id) or 32
    char = char - 32
    if char > 64 then
      char = char - 32
    elseif char < 0 then
      char = 0
    end
    for delta=2,0,-1 do
      local posid = 1 + (char_id-1) * 3 + 2 - delta
      local val = math.floor(char / 4^delta)
      char = char - (val * 4^delta)
      bits[posid] = val
    end
  end
  return bits
end

function private.bitsToName(bits)
  local s = ''
  for char_id=1,22 do
    val = 0
    for delta=0,2 do
      local posid = 1 + (char_id-1) * 3 + 2 - delta
      val = val + bits[posid] * 4^delta
    end
    if val == 0 then
      s = s .. ' '
    else
      s = s .. string.char(val + 32)
    end
  end
  return s
end
