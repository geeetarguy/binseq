--[[------------------------------------------------------

  seq.LSongsView
  --------------

  This view shows the list of songs:

  ( usual global commands )
  [ Green = selected, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'seq.LSongsView', name = 'Songs'}
lib.__index        = lib
seq.LSongsView     = lib
-- Map top buttons
local top_button   = {}
local private      = {}
private.nameToBits = seq.LHomeView.common.nameToBits
local gridToPosid  = seq.Event.gridToPosid 
local posidToGrid  = seq.Event.posidToGrid
local BIT_STATE    = seq.LHomeView.common.BIT_STATE

--=============================================== CONSTANTS

local SONG_STATE = {
  'LightAmber', -- has song (amber color)
  'LightGreen', -- has song (green color)
  'LightRed',   -- has song (red color)
  'Green',      -- selected
}

--=============================================== PUBLIC
setmetatable(lib, {__call = function(lib, ...) return lib.new(...) end})

-- seq.LSongsView(...)
function lib.new(lseq)
  local self = {
    lseq = lseq,
    pad  = lseq.pad,
    song = lseq.song,
    -- default pagination
    page = 0,
    songs = {},
  }

  -- patterns by posid
  self.songs = private.loadSongs(self)

  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display()
  local pad  = self.pad
  local song = self.song
  local songs= self.songs
  local curr = (song or {}).posid
  local page = self.page
  -- Clear
  pad:prepare()
  pad:clear()
  pad:button(0, 1):setState('Amber')

  -- Display songs
  for row=1,8 do
    for col=1,8 do
      local posid = gridToPosid(row, col, page)
      local song  = songs[posid]
      if song then
        private.showButtonState(self, song, row, col)
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

function lib:setEventState(e)
  local song  = e.pat.song
  local posid = song.posid
  private.showButtonState(self, song, nil, nil, e)
end

--[[
--=============================================== TOP BUTTONS
-- Copy/Del pattern
top_button[5] = function(self, row, col)
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

  if self.key == 'mixer' then
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

    --if self.copy_on then
    --  if self.event then
    --    -- copy
    --    e = self.seq:setEvent(posid, self.event)
    --    e.mute = 1
    --  else
    --    return
    --  end
    --  self.copy_on = false
    --  self.copy_btn:setState('Off')
    --elseif self.del_on == e.posid then
    --  -- delete
    --  self.del_on = false
    --  self.pad:button(0, 5):setState('Off')

    --  self.seq.pattern:deleteEvent(e)
    --  self.pad:button(row, col):setState('Off')
    --  if e == self.event then
    --    -- clear
    --    self.event = nil
    --    self.btn   = nil
    --    self:display()
    --  end
    --  return
    --elseif self.del_on then
    --  self.del_on = e.posid
    --  self.pad:button(row, col):setState('Red')
    --  return
    --end
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

function private:assignSequencer(song, pat, col)
  if not col then
    local r, c = posidToGrid(pat.posid, 0)
    col = c
    print('assignSequencer', pat.posid, col, p)
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
--]]

function private:showButtonState(song, row, col, e)
  if song.posid == self.lseq.song.posid then
    self.pad:button(row, col):setState('Green')
    return
  end

  if not row then
    row, col = posidToGrid(song.posid, self.page)
    if not row then
      return
    end
  end
  local b = private.nameToBits(self, song, true)
  if e and e.off_t then
    -- + NoteOn
    b = b + 2
  end
  self.pad:button(row, col):setState(BIT_STATE[b] + 1)
end


function private:loadSongs()
  local list = {}
  for s in self.lseq.db:getSongs() do
    list[s.posid] = s
  end
  return list
end
