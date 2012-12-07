--[[------------------------------------------------------

  binseq.LHomeView
  ----------------

  This view shows the following elements:

  ( usual global commands )
  [ Green = playing, Red = playing + auto-save, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'binseq.LHomeView', name = 'Home'}
lib.__index         = lib
binseq.LHomeView     = lib
-- Last column operation to function
local col_button    = {}
-- Map top buttons
local top_button    = {}
local private       = {}
local m             = binseq.LMainView.common
local gridToPosid   = binseq.Event.gridToPosid 
local posidToGrid   = binseq.Event.posidToGrid

--=============================================== CONSTANTS
-- Last column button parameter selection
local PARAMS      = m.PARAMS

local BIT_STATE = {
  'Off', 
  'Green',
  'Amber',
  'Red',
  'LightRed',
}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- binseq.LHomeView(...)
function lib.new(lseq, song)
  local self = {
    lseq = lseq,
    pad  = lseq.pad,
    -- default pagination
    page = 0,
    song = song,
    patterns = {},
  }

  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display(key)
  local song = self.song
  if song then
    key = song.name
  end
  self.key = key or self.key
  self.name_bits = private.nameToBits(self, self.key or '')

  local pad  = self.pad
  local bits = self.name_bits
  local page = self.page
  -- Clear
  pad:prepare()
  pad:clear()
  -- Display patterns
  -- Turn on 'pattern' button
  if self.song then
    pad:button(0, 1):setState('Red')
  end

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
    if col == 8 or col == 1 then
      -- pass to LSeq
    else
      -- ignore here
      return
    end
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
  local name = private.bitsToName(self.name_bits)
  local song = self.lseq.song
  if song then
    song:set {
      name = name
    }
  end
  self.key = name
  print('==>'..name..'<==')
end

function private:nameToBits(name, first)
  local bits = {}
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
      if first and val > 0 then
        -- Return just the first non-zero bit (used in LSongsView).
        return val
      end
      char = char - (val * 4^delta)
      bits[posid] = val
    end
  end
  if first then
    -- any color
    return 2
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

col_button[8] = function(self, row, col)
  self.lseq:loadView('Life')
end

lib.common = {
  nameToBits = private.nameToBits,
  BIT_STATE  = BIT_STATE,
}
