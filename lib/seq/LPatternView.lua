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
  'LightGreen', -- active or edited
  'Amber',      -- + NoteOn
  'Green',      -- + NoteOn
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
function lib:display(key)
  -- TODO: Copy operation => copied object in LSeq and check type on display
  key = key or 'mixer'
  self.key = key
  local pad  = self.pad
  local song = self.song
  local curr = (song.edit_pattern or {}).posid
  local page = self.page
  -- Clear
  pad:prepare()
  for i=1,8 do
    pad:button(0, i):setState('Off')
  end
  self.pad:button(0, 4):setState(self.toggle and 'Green' or 'Off')
  -- Display patterns
  if key == 'pattern' then
    -- Turn on 'sequencer' buttons
    for col=1,8 do
      if song.sequencers[col] then
        pad:button(0, col):setState('Green')
      end
    end
    pad:button(1, 9):setState('Amber')
  else
    if self.copy_on then
      pad:button(0, 5):setState('Green')
      pad:button(0, 8):setState('Green')
    elseif self.del_on then
      pad:button(0, 5):setState('Red')
      pad:button(0, 8):setState('Red')
    else
      pad:button(0, 5):setState('Off')
      pad:button(0, 8):setState('Amber')
    end
  end
  pad:commit()
  private.showGrid(self)
end

function lib:release(row, col)
  if self.key == 'pattern' then
    self.lseq:release(row, col)
  end
  if self.toggle and row > 0 and col < 9 then
    self:press(row, col)
  end
end

function lib:press(row, col)
  local f
  if row == 0 then
    if self.key == 'pattern' then
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

function lib:setEventState(e)
  local pat = e.pat
  local posid = pat.posid
  private.showButtonState(self, pat, nil, nil, e)
end

--=============================================== TOP BUTTONS
-- Copy/Del pattern
top_button[5] = function(self, row, col)
  if self.copy_on then
    self.copy_on = false
    self.del_on = true
  elseif self.del_on then
    self.del_on = false
  else
    -- enable copy
    self.copy_on = true
  end
  self:display()
end

-- Toggle playback mode
top_button[4] = function(self, row, col)
  self.toggle = not self.toggle
  self.pad:button(row, col):setState(self.toggle and 'Green' or 'Off')
end

--=============================================== GRID
function private:pressGrid(row, col)
  local pad = self.pad
  local song = self.song
  local posid = gridToPosid(row, col, self.page)
  local pat = self.patterns[posid]
                     


  if self.copy_on then
    --=============================================== FIXME !!!
    if song.edit_pattern then
      -- copy
      self.patterns[posid] = song.db:copyPattern(posid, song.edit_pattern)
    else
      return
    end
    self.copy_on = false
    self:display()
  elseif self.del_on == pat then
    -- delete
    self.del_on = true
    pat:delete()
    self.patterns[posid] = nil
    if pat == song.edit_pattern then
      -- clear
      song.edit_pattern = nil
    end
    self:display()

  elseif self.del_on then
    if type(self.del_on) == 'table' then
      private.showButtonState(self, self.del_on)
    end
    self.del_on = true
    if pat then
      self.del_on = pat
      pad:button(row, col):setState('Red')
    end
  elseif self.key == 'mixer' then
    -- enable patterns for sequencer playback
    local pat = song.patterns[posid]
    if pat then
      if pat.seq then
        pat:setSequencer(nil)
      else
        -- Find sequencer for this pattern
        private.assignSequencer(self, song, pat, col)
      end
      private.showButtonState(self, pat, row, col)
    end

  else
    -- choose pattern to edit
    local pat = song:getOrCreatePattern(posid)
    local last_pat = song.edit_pattern
    song.edit_pattern = pat

    if last_pat then
      private.showButtonState(self, last_pat)
    end
    private.showButtonState(self, pat, row, col)
  end
end

function private:sequencerPress(row, col)
  local song = self.song
  local aseq = song.sequencers[col]
  if aseq then
    -- remove
    aseq:delete()
    song.sequencers[col] = nil
    for posid, pat in pairs(aseq.patterns) do
      private.assignSequencer(self, song, pat)
    end

    self.pad:button(0, col):setState('Off')
  else
    local aseq = song:getOrCreateSequencer(col)
    aseq:set {
      channel = col
    }
    aseq.playback = self.lseq.playback

    for _, pat in pairs(song.patterns) do
      if pat.seq then
        private.assignSequencer(self, song, pat)
      end
    end
    self.pad:button(0, col):setState('Green')
  end
end

function private:showButtonState(pat, row, col, e)
  if not row then
    row, col = posidToGrid(pat.posid, self.page)
    if not row then
      return
    end
  end
  local b
  if self.key == 'mixer' and not self.copy_on and not self.del_on then
    b = pat.seq and 3 or 2
  else
    b = self.song.edit_pattern == pat and 3 or 2
  end
  if e and e.off_t then
    -- + NoteOn
    b = b + 2
  end
  self.pad:button(row, col):setState(PART_STATE[b])
end


function private:assignSequencer(song, pat, col)
  if not col then
    local r, c = posidToGrid(pat.posid, 0)
    col = c
  end

  local seq
  for i=col,1,-1 do
    seq = song.sequencers[i]
    if seq then
      break
    end
  end
  if seq then
    pat:setSequencer(seq)
  end
end

function private:showGrid()
  local page  = self.page
  local parts = self.patterns
  local pad   = self.pad

  for row=1,8 do
    for col=1,8 do
      local posid = gridToPosid(row, col, page)
      local pat = parts[posid]
      if pat then
        private.showButtonState(self, pat, row, col)
      else
        pad:button(row, col):setState('Off')
      end
    end
  end
end
