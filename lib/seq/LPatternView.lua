--[[------------------------------------------------------

  seq.LPatternView
  ---------------

  This view shows the following elements:

  ( usual global commands )
  [ Green = playing, Red = playing + auto-save, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'seq.LPatternView', name = 'Pattern'}
lib.__index         = lib
seq.LPatternView     = lib
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

-- seq.LPatternView(...)
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
  self.patterns = song.patterns

  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display(mode)
  self.mode = mode or 'mixer'
  local pad  = self.pad
  local song = self.song
  local parts = self.patterns
  local curr = (song.edit_pattern or {}).posid
  local page = self.page
  -- Clear
  pad:prepare()
  pad:clear()
  -- Display patterns
  -- Turn on 'sequencer' buttons
  for col=1,8 do
    if song.sequencers[col] then
      pad:button(0, col):setState('Green')
    end
  end

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

function lib:release(row, col)
  if self.mode == 'pattern' then
    self.lseq:release(row, col)
  end
end

function lib:press(row, col)
  local f
  if row == 0 then
    if self.mode == 'pattern' then
      f = private.sequencerPress
    else
      f = top_button[col]
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
  local curr = (seq.pattern or {}).posid
  if curr then
    local cr, cc = posidToGrid(curr, self.page)

    if cr then
      pad:button(cr, cc):setState(PART_STATE[2])
    end
  end

  if self.copy_on then
    if posid ~= seq.pattern.posid then
      -- copy current pattern to given location
      seq.db:copyPattern(seq.pattern, posid)
    end
    self.copy_on = false
    pad:button(0, 5):setState('Off')
    pad:button(row, col):setState(PART_STATE[2])
    return
  elseif self.del_on == posid then
    -- delete
    local p = seq.db:getPattern(posid)
    -- FIXME: preset views in other sequencers should be notified
    p:delete()
    self.del_on = nil
    self.pad:button(0, 5):setState('Off')
    self.patterns[p.posid] = nil
    if p.posid ~= (self.seq.pattern or {}).posid then
      pad:button(row, col):setState(PART_STATE[1])
    else
      pad:button(row, col):setState(PART_STATE[1])
      self.seq:selectPattern(1)
      self.patterns[1] = true
    end
    return
  elseif self.del_on then
    if seq.db:hasPattern(posid) then
      self.del_on = posid
      pad:button(row, col):setState(PART_STATE[5])
    end
    return
  end

  local cposid = (self.seq.pattern or {}).posid
  if cposid == posid then
    -- turn off
    self.seq:selectPattern(nil)
    self.patterns[posid] = false
    pad:button(row, col):setState(PART_STATE[2])
  else
    -- Change pattern (creates new if needed)
    self.seq:selectPattern(posid)
    self.patterns[posid] = true
    pad:button(row, col):setState(PART_STATE[4])
  end
end

function private:sequencerPress(row, col)
  local song = self.song
  local aseq = song.sequencers[col]
  if aseq then
    -- remove
    aseq:delete()
    song.sequencers[col] = nil
    self.pad:button(0, col):setState('Off')
  else
    song:getOrCreateSequencer(col)
    self.pad:button(0, col):setState('Green')
  end
end

