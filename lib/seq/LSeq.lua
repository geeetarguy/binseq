--[[------------------------------------------------------

  seq.LSeq
  --------

  Controller between the Launchpad and the sequencer.

--]]------------------------------------------------------
local lib = {type = 'seq.LSeq'}
lib.__index         = lib
seq.LSeq            = lib
local private       = {}
local top_button    = {}
local col_press     = {}
local col_release   = {}
local m             = seq.LMainView.common
local PARAMS        = m.PARAMS

--=============================================== CONSTANTS
local SEQ_BITS = {4, 2, 1}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LSeq(...)
function lib.new(name, db_path)
  local self = {
    name = name,
    pad = seq.Launchpad(),
    views = {},
    sequencers = {},
    seq_list   = {},
    -- buttons on the right
    seq_bits = {},
    selected_id  = 1,
    selected_seq = nil,
    db = seq.PresetDb(db_path or name .. '.db'),
  }

  setmetatable(self, lib)

  private.setupMidi(self)

  self:loadSong(1)
  return self
end

function lib:loadSong(posid)
  local song = self.db:getOrCreateSong(posid)
  self.song = song

  -- Prepare to be used with Launchpad views.
  song.views = {}
  local seq
  for _, s in pairs(song.sequencers) do
    if not seq then
      seq = s
    end
    s.playback = self.playback
  end

  if not seq then
    -- Create 1
    seq = self.song:getOrCreateSequencer(1)
    seq.playback = self.playback
  end

  local pattern
  for k, p in pairs(song.patterns) do
    pattern = p
    break
  end

  if not pattern then
    pattern = self.song:getOrCreatePattern(1)
    seq:enablePattern(1)
  end
  song.edit_pattern = pattern

  self:loadView 'Home'
end

function lib:loadView(name, key)
  local song = self.song

  --if name ~= 'Pattern' and not song.edit_pattern then
  --  return -- refuse to leave pattern page
  --end

  if self.view then
    if name == self.view.name and key == self.view.key then
      -- load last
      self:loadView(self.last_name or 'Home', self.last_key)
      return
    end
    self.last_name = self.view.name
    self.last_key = self.view.key
  end

  local view = song.views[name]
  if not view then
    local t = seq['L'..name..'View']
    if t then
      view = t(self, song)
      song.views[name] = view
    else
      error('Could not find seq.L'..name..'View view')
    end
  end

  self.view = view
  self.pad:loadView(view, key)
end

function lib:reScheduleAll(t)
  for _, aseq in pairs(self.song.sequencers) do
    aseq:move(t)
  end
end

function lib:trigger(t)
  for _, aseq in pairs(self.song.sequencers) do
    -- Loop through all sequencers
    aseq.t = t
    list = aseq.list
    local e = list.next
    while e and e.t <= t do
      aseq:trigger(e)
      e = list.next
    end
  end
end

function lib:release(row, col)
  if row == 1 and col == 9 then
    -- End of pattern select
    local last, key = self.last_name, self.last_key
    self:loadView(last, key)
    -- Do not change last
    self.last_name = self.plast
    self.last_key = self.pkey
  elseif col == 9 then
    local f = col_release[row]
    if f then
      f(self, row, col)
    end
  end
end

-- Default actions when not implemented in view.
function lib:press(row, col)
  local f
  if row == 0 then
    f = top_button[col]
  elseif col == 9 then
    f = col_press[row]
  end
  if f then
    f(self, row, col)
  end
end

--=============================================== TOP BUTTONS
-- Select song
top_button[1] = function(self, row, col)
  self:loadView('Songs')
end

-- Show mixer
top_button[8] = function(self, row, col)
  self:loadView('Pattern', 'mixer')
end

--=============================================== COLUMN BUTTONS
-- Show pattern select
col_press[1] = function(self, row, col)
  -- store previous last
  self.plast, self.pkey = self.last_name, self.last_key
  self:loadView('Pattern', 'pattern')
end

col_press[2] = function(self, row, col)
  self:loadView('Main')
end

col_press[3] = function(self, row, col)
  self:loadView('Rec')
end

for i, key in ipairs(PARAMS) do
  if key ~= '' then
    col_press[i] = function(self, row, col)
      self:loadView('Batch', key)
    end
  end
end

-- release is captured or ignored by loaded view

--[[
function lib:selectSequencer(posid)
  -- current view
  local aseq = self.selected_seq
  local view_name = 'Preset'
  local view_key
  if aseq then
    -- keep same view
    view_name = aseq.view.name
    view_key = aseq.view.key
    if not aseq.pattern then
      -- unstarted sequencer, remove
      for i, s in ipairs(self.seq_list) do
        if s == aseq then
          table.remove(self.seq_list, i)
          break
        end
      end
      self.sequencers[self.selected_id] = nil
    end
  end

  local aseq = self.sequencers[nb]
  if not aseq then
    view_name = 'Preset'
    aseq = seq.Sequencer(self.db_path)
    aseq.channel = nb
    aseq.views = {}
    self.sequencers[nb] = aseq
    table.insert(self.seq_list, aseq)
    -- Share client callback with all sequencers.
    aseq.playback = self.playback

    -- Change trigger so that we are also notified.
    local trigger = aseq.trigger
    function aseq.trigger(aseq, e)
      -- Normal sequencer trigger function
      trigger(aseq, e)

      -- Our notification to show highlighted notes
      if self.selected_seq == aseq then
        local view = aseq.view
        local f = view.setEventState
        if f then
          f(view, e)
        end
      end
    end
  end

  self.selected_id  = nb
  self.selected_seq = aseq
  self:loadView(view_name, view_key)
end

function lib:showSeqButtons()
  -- Highlight bits
  local nb = self.selected_id - 1
  local bits = self.seq_bits
  for i, r in ipairs(SEQ_BITS) do
    local b = math.floor(nb/r)
    if b > 0 then
      self.pad:button(i, 9):setState('Green')
    else
      self.pad:button(i, 9):setState('LightRed')
    end
    bits[i] = b
    nb = nb - r * b
  end
end


-- Last column buttons
function private:batchButton(row, col)
  local key = PARAMS[row]
  self:loadView('Batch', key)
end
for i, key in ipairs(PARAMS) do
  if key ~= '' then
    col_press[i] = private.batchButton
  end
end

function private:presetButton(row, col)
  self:loadView('Preset')
end
top_button[6] = private.presetButton

function private:recButton(row, col)
  self:loadView('Rec')
end
top_button[4] = private.recButton

function private:seqButton(row, col)
  local nb = self.selected_id - 1
  local bits = self.seq_bits

  if bits[row] == 1 then
    nb = nb - SEQ_BITS[row]
  else
    nb = nb + SEQ_BITS[row]
  end

  self:selectSequencer(nb + 1)
end
col_press[1] = private.seqButton
col_press[2] = private.seqButton
col_press[3] = private.seqButton

-- function private:recButton(row, col)
--   self:loadView('Rec')
-- end
-- Default actions when not implemented in view.
function lib:release(row, col)
end

function lib:record(msg)
  local rec = self.views['Rec']
  if rec then
    rec:record(msg)
  end
end

--]]

function private:setupMidi()
  local midiout = midi.Out()
  midiout:virtualPort(self.name)

  self.midiout = midiout
  function self.playback(aseq, e)
    -- Playback function
    -- Important to trigger so that NoteOff is registered.
    midiout:send(e:trigger(aseq.channel))
    local view = self.view
    local f = view.setEventState
    if f then
      f(view, e)
    end
  end

  local midiin = midi.In()
  midiin:virtualPort(self.name)
  -- do not ignore midi sync
  midiin:ignoreTypes(true, false, true)
  self.midiin = midiin


  --============================ midi in hook
  local t = 0
  local running = false
  function midiin.receive(midiin, msg)
    if msg.type == 'Clock' then
      local op = msg.op
      if running and op == 'Tick' then

        self:trigger(t)
        -- Prepare time for next run in case events are re-scheduled or 
        -- created.
        t = t + 1
      elseif op == 'Continue' and not running then
        -- Next tick = t
        running = true
      elseif op == 'Start' and not running then
        -- Next tick = beat 0
        t = 0
        self:reScheduleAll(t)
        running = true
      elseif op == 'Stop' and running then
        running = false
      elseif op == 'Song' then
        t = msg.position
        self:reScheduleAll(t)
      end
    else
      ls:record(msg)
    end
  end
end
