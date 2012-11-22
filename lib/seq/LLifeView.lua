--[[------------------------------------------------------

  seq.LLifeView
  -------------

  Conway's game of life.

--]]------------------------------------------------------
local lib = {type = 'seq.LLifeView', name = 'Life'}
lib.__index        = lib
seq.LLifeView      = lib
-- Map top buttons
local top_button   = {}
local col_button   = {}
local private      = {}
private.nameToBits = seq.LHomeView.common.nameToBits
local gridToPosid  = seq.Event.gridToPosid 
local posidToGrid  = seq.Event.posidToGrid
local BIT_STATE    = seq.LHomeView.common.BIT_STATE

--=============================================== CONSTANTS

local LIFE_STATE = {
  'Off',
  'Green',
}

--=============================================== PUBLIC
setmetatable(lib, {__call = function(lib, ...) return lib.new(...) end})

-- seq.LLifeView(...)
function lib.new(lseq)
  local self = {
    lseq = lseq,
    pad  = lseq.pad,
    life = {},
  }

  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display()
  local pad  = self.pad
  local song = self.lseq.song

  -- Clear
  pad:prepare()
  pad:clear()
  pad:button(0, 1):setState('Red')
  pad:button(8, 9):setState('Green')

  -- Init life
  private.initLife(self, song.name)
  private.showLife(self)
  function self.lseq.animate()
    self:stepLife()
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
  -- ignore
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

col_button[8] = function(self, row, col)
  self.lseq:loadView('Home')
end
--=============================================== GRID
function private:pressGrid(row, col)
  local life = self.life
  local posid = col + 2 + row*10
  life[posid] = life[posid] == 1 and 0 or 1
  self.pad:button(row, col):setState(LIFE_STATE[life[posid]+1])
end

function private:initLife(name)
  local life = self.life
  bits = private.nameToBits(self, name)
  for row=1,8 do
    for col=1,8 do
      -- 1 cell margin on all sides
      local gpos  = gridToPosid(row, col, 0)
      local posid = col + 2 + row*10
      life[posid] = bits[gpos] > 0 and 1 or 0
    end
  end
end

function private:showLife()
  local life = self.life
  local pad = self.pad
  for row=1,8 do
    for col=1,8 do
      local posid = col + 2 + row*10
      pad:button(row, col):setState(LIFE_STATE[life[posid]+1])
    end
  end
end

local DELTAS = {
  -11, -10,  -9,
   -1,        1,
    9,  10,  11,
}

function lib:stepLife()
  -- Grid is 10x10 (1 margin)
  local a = self.life
  local b = {}
  for row=1,8 do
    for col=1,8 do
      local i = col + 2 + row*10
      local n = 0
      for _, d in ipairs(DELTAS) do
        -- border is 0
        n = n + (a[i+d] or 0)
      end

      if a[i] == 1 then
        -- Live cell
        if n < 2 then
          -- Any live cell with fewer than two live neighbours dies, as if caused by under-population.
          b[i] = 0
        elseif n < 4 then
          -- Any live cell with two or three live neighbours lives on to the next generation.
          b[i] = 1
        else
          -- Any live cell with more than three live neighbours dies, as if by overcrowding.
          b[i] = 0
        end
      else
        -- Dead cell
        if n == 3 then
          -- Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
          b[i] = 1
        else
          b[i] = 0
        end
      end
    end
  end

  self.life = b
  private.showLife(self)
end
