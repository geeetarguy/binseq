--[[------------------------------------------------------

  binseq.LPatternView
  -------------------

  This view shows the following elements:

  ( usual global commands )
  [ Green = playing, Red = playing + auto-save, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'binseq.LPatternView', name = 'Pattern'}
lib.__index         = lib
binseq.LPatternView     = lib
-- Last column operation to function
local col_button    = {}
-- Map top buttons
local top_button    = {}
local private       = {}
local m             = binseq.LMainView.common
local gridToPosid   = binseq.Event.gridToPosid 
local posidToGrid   = binseq.Event.posidToGrid
local POS           = m.POS
private.showCopyDel = m.showCopyDel

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

-- binseq.LPatternView(...)
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
function lib:display(key, opt)
  -- TODO: Copy operation => copied object in LSeq and check type on display
  key = key or 'mixer'
  self.key = key
  if key == 'pattern' then
    self.copy = nil
    self.del = nil
  end
  local pad  = self.pad
  local song = self.song
  local curr = (song.edit_pattern or {}).posid
  local page = self.page

  if opt == 'extra' then
    -- extra adds 8 channels and 64 patterns.
    self.extra = not self.extra
  end

  if self.extra then
    self.offset = 8
  else
    self.offset = 0
  end

  for col=1,8 do
    if key == 'pattern' then
      if song.sequencers[col + self.offset] then
        if self.extra then
          pad:button(0, col):setState('Red')
        else
          pad:button(0, col):setState('Green')
        end
      elseif col == POS.EXTRA and self.extra then
        pad:button(0, col):setState('Amber')
      else
        pad:button(0, col):setState('Off')
      end
    elseif col == POS.EXTRA and self.extra then
      pad:button(0, col):setState('Amber')
    elseif col == POS.COPY then
      private.showCopyDel(self, col)
    elseif col == POS.TOGGLE then
      pad:button(0, col):setState(self.toggle and 'Green' or 'Off')
    elseif col == POS.MIXER then
      pad:button(0, col):setState('Amber')
    else
      pad:button(0, col):setState('Off')
    end
  end

  for row=1,8 do
    if row == POS.SEQ and key == 'pattern' then
      pad:button(row, 9):setState('Amber')
    else
      pad:button(row, 9):setState('Off')
    end
  end 
  
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

-- Called on next pattern trigger.
function lib:enablePattern(pat, row, col)
  local song = pat.song
  local row, col
  if not row then
    row, col = posidToGrid(pat.posid, self.page, 8, 16, self.offset)
  end

  local seq
  for i=col+self.offset,1,-1 do
    seq = song.sequencers[i]
    if seq then
      break
    end
  end
  if seq then
    seq:enablePattern(pat.posid)
  end

  if self.lseq.view == self then
    private.showButtonState(self, pat, row, col)
  end
end

-- Called on next pattern trigger.
function lib:disablePattern(pat, row, col)
  local row, col = row, col
  if not row then
    row, col = posidToGrid(pat.posid, self.page, 8, 16, self.offset)
  end

  local aseq = pat.seq
  if aseq then
    aseq:disablePattern(pat.posid)
  end

  if self.lseq.view == self then
    private.showButtonState(self, pat, row, col)
  end
end

--=============================================== TOP BUTTONS
-- Copy/Del pattern
top_button[POS.COPY] = function(self, row, col)
  if self.copy then
    if type(self.copy) == 'table' then
      self.copy = nil
      self.del = nil
    else
      self.copy = nil
      self.del = true
    end
  elseif self.del then
    self.del = nil
  else
    self.copy = true
  end
  -- During copy or delete: do not display enabled/playing patterns.
  self:display(self.key)
end

-- Toggle playback mode
top_button[POS.TOGGLE] = function(self, row, col)
  self.toggle = not self.toggle
  self.pad:button(row, col):setState(self.toggle and 'Green' or 'Off')
end

--=============================================== GRID
function private:pressGrid(row, col)
  local pad = self.pad
  local song = self.song
  local posid = gridToPosid(row, col, self.page, 8, 16, self.offset)
  local pat = self.patterns[posid]
                     

  if self.copy == true then
    if pat then
      self.copy = yaml.dump(pat:dump())
      self.pad:button(0, POS.COPY):setState('Green')
    end
  elseif self.copy then
    pat = pat or song:getOrCreatePattern(posid)
    self.patterns[posid] = pat
    pat:copy(yaml.load(self.copy))
    -- Stop copy operation
    self.copy = nil
    self.pad:button(0, POS.COPY):setState('Off')
    private.showButtonState(self, pat)
  elseif type(self.del) == 'table' then
    if self.del == pat then
      pat:delete()
      self.patterns[posid] = nil
    end
    self.del = nil
    self:display()
  elseif self.del then
    self.del = pat
    self.pad:button(row, col):setState('Red')
  elseif self.key == 'mixer' then
    -- enable patterns for sequencer playback
    local pat = song.patterns[posid]
    if pat then
      if pat.seq then
        self:disablePattern(pat, row, col)
      else
        -- Find sequencer for this pattern
        self:enablePattern(pat, row, col)
      end
    end

  else
    -- choose pattern to edit
    local pat = song.patterns[posid]
    if not pat then
      pat = song:getOrCreatePattern(posid)
      self:enablePattern(pat, row, col)
    end
    local last_pat = song.edit_pattern
    song.edit_pattern = pat

    if last_pat then
      private.showButtonState(self, last_pat)
    end
    private.showButtonState(self, pat, row, col)
  end
end

function private:sequencerPress(row, col)
  local chan = self.offset + col
  local song = self.song
  local aseq = song.sequencers[chan]
  if aseq then
    -- remove
    aseq:delete()
    song.sequencers[chan] = nil
    for posid, pat in pairs(aseq.patterns) do
      -- Change sequencer
      self:enablePattern(pat)
    end

    if col == POS.EXTRA and self.extra then
      self.pad:button(0, col):setState('Amber')
    else
      self.pad:button(0, col):setState('Off')
    end
  else
    local aseq = song:getOrCreateSequencer(chan)
    aseq:set {
      channel = chan
    }
    aseq.playback = self.lseq.playback

    for _, pat in pairs(song.patterns) do
      if pat.seq then
        self:enablePattern(pat)
      end
    end

    if self.extra then
      self.pad:button(0, col):setState('Red')
    else
      self.pad:button(0, col):setState('Green')
    end
  end
end

function private:showButtonState(pat, row, col, e)
  if not row then
    row, col = posidToGrid(pat.posid, self.page, 8, 16, self.offset)
  end
  if not row or col > 8 or col < 1 or row > 8 then return end
  local b
  if self.copy or self.del then
    b = 2
  elseif self.key == 'mixer' then
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


function private:showGrid()
  local parts  = self.patterns
  local pad    = self.pad
  -- next 16 channels (right to current 64 elements)
  local offset = self.offset
  -- bellow current 2x64 elements
  local page   = self.page

  for row=1,8 do
    for col=1,8 do
      local posid = gridToPosid(row, col, page, 8, 16, offset)
      local pat = parts[posid]
      if pat then
        private.showButtonState(self, pat, row, col)
      else
        pad:button(row, col):setState('Off')
      end
    end
  end
end
