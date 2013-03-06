--[[------------------------------------------------------

  binseq.LSongsView
  -----------------

  This view shows the list of songs:

  ( usual global commands )
  [ Green = selected, Amber = exist ]

--]]------------------------------------------------------
local lib = {type = 'binseq.LSongsView', name = 'Songs'}
lib.__index        = lib
binseq.LSongsView     = lib
-- Map top buttons
local top_button    = {}
local private       = {}
local m             = binseq.LMainView.common
private.nameToBits  = binseq.LHomeView.common.nameToBits
local gridToPosid   = binseq.Event.gridToPosid 
local posidToGrid   = binseq.Event.posidToGrid
local POS           = m.POS
private.showCopyDel = m.showCopyDel


--=============================================== CONSTANTS

local SONG_STATE = {
  'Off', 
  'LightGreen', -- has song (green color)
  'LightAmber', -- has song (amber color)
  'LightRed',   -- has song (red color)
  'Green',      -- selected
}

--=============================================== PUBLIC
setmetatable(lib, {__call = function(lib, ...) return lib.new(...) end})

-- binseq.LSongsView(...)
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
  private.showCopyDel(self, POS.COPY)

  -- Display songs
  for row=1,8 do
    for col=1,8 do
      local posid = gridToPosid(row, col, page)
      local song  = songs[posid]
      if song then
        private.showButtonState(self, song, row, col)
      else
        pad:button(row, col):setState 'Off'
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
    if row == POS.EXPORT then
      f = private.export
    elseif row == POS.IMPORT then
      f = private.import
    else
      -- pass to LSeq
    end
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


--=============================================== TOP BUTTONS
-- Copy/Del pattern
top_button[POS.COPY] = function(self, row, col)
  local btn = self.pad:button(row, col)
  if self.copy then
    if type(self.copy) == 'table' then
      self.copy = nil
      self.del = nil
      btn:setState('Off')
    else
      self.copy = nil
      self.del = true
      btn:setState('Red')
    end
  elseif self.del then
    self.del = nil
    btn:setState('Off')
  else
    self.copy = true
    btn:setState('Amber')
  end
end

--=============================================== GRID
function private:pressGrid(row, col)
  local pad  = self.pad
  local song = self.song
  local posid = gridToPosid(row, col, self.page)
  local db = self.lseq.db

  local song = self.songs[posid]

  if self.copy == true then
    if song then
      self.copy = yaml.dump(song:dump())
      self.pad:button(0, POS.COPY):setState('Green')
    end
  elseif self.copy then
    if song then
      song:delete()
    end
    song = db:getOrCreateSong(posid)
    self.songs[posid] = song
    song:copy(yaml.load(self.copy))
    for _, seq in pairs(song.sequencers) do
      seq.playback = self.lseq.playback
    end
    self.copy = nil
    self.pad:button(0, POS.COPY):setState('Off')
    private.showButtonState(self, song)
  elseif type(self.del) == 'table' then
    if self.del == song then
      song:delete()
      self.songs[posid] = nil
    end
    self.del = nil
    self:display()
  elseif self.del then
    self.del = song
    self.pad:button(row, col):setState('Red')
  else
    self.lseq:loadSong(posid)
  end
end

function private:showButtonState(song, row, col, e)
  if not row then
    row, col = posidToGrid(song.posid, self.page)
    if not row then
      return
    end
  end

  local b
  if self.lseq.song and song.posid == self.lseq.song.posid then
    b = 4
  else
    b = private.nameToBits(self, song.name, true)
  end

  self.pad:button(row, col):setState(SONG_STATE[b + 1])
end


function private:loadSongs()
  local list = {}
  for s in self.lseq.db:getSongs() do
    list[s.posid] = s
  end
  return list
end

local BASE_PATH = '/Road64_song.yml'

function private:export(row, col)
  -- Export current song
  if type(self.copy) == 'string' then
    local filepath = os.getenv('HOME')..BASE_PATH
    local f = io.open(filepath, 'wb')
    if f then
      local s = f:write(self.copy)
      f:close()
    end
    self.copy = nil
    private.showCopyDel(self, POS.COPY)
  end
end

function private:import(row, col)
  -- Copy song
  local filepath = os.getenv('HOME')..BASE_PATH
  local f = io.open(filepath, 'rb')
  if f then
    self.copy = f:read('*a')
    private.showCopyDel(self, POS.COPY)
  end
end
