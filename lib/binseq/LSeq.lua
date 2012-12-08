--[[------------------------------------------------------

  binseq.LSeq
  -----------

  Controller between the Launchpad and the sequencer.

--]]------------------------------------------------------
local lib = {type = 'binseq.LSeq'}
lib.__index         = lib
binseq.LSeq            = lib
local private       = {}
local top_button    = {}
local col_press     = {}
local col_release   = {}
local m             = binseq.LMainView.common
local PARAMS        = m.PARAMS
local POS           = m.POS

--=============================================== CONSTANTS
local SEQ_BITS = {4, 2, 1}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- binseq.LSeq(...)
function lib.new(db_path, out_name, in_name, pad_name)
  assert(db_path, 'Database path needed.')
  local self = {
    out_name = out_name,
    in_name  = in_name,
    pad_name = pad_name,
    views = {},
    sequencers = {},
    seq_list   = {},
    -- buttons on the right
    seq_bits = {},
    selected_id  = 1,
    selected_seq = nil,
    db = binseq.PresetDb(db_path),
  }

  setmetatable(self, lib)

  self:connect()
  return self
end

function lib:loadSong(posid)
  local song = self.db:getOrCreateSong(posid)
  self.song = song
  if song.name == '' then
    -- new song
    -- This is a red square in the middle.
    song.name = '         \\ #P         '
  end

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
    aseq.playback = self.playback
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

function lib:loadView(name, key, opt)
  -- Reset animation
  self.animate = nil

  local song = self.song

  if name == 'Home' or name == 'Songs' or name == 'Life' then
    -- always OK
  elseif not song then
    -- not OK
    return
  elseif name ~= 'Pattern' and not song.edit_pattern then
    -- not OK
    return
  end

  if self.view then
    if not opt then
      if name == self.view.name and key == self.view.key then
        -- load last
        self:loadView(self.last_name or 'Home', self.last_key)
        return
      end
      self.last_name = self.view.name
      self.last_key = self.view.key
    end
  end

  local view = song and song.views[name]
  if not view then
    local t = binseq['L'..name..'View']
    if t then
      view = t(self, song)
      if song then
        song.views[name] = view
      end
    else
      error('Could not find binseq.L'..name..'View view')
    end
  end

  self.view = view
  self.pad:loadView(view, key, opt)
end

function lib:reScheduleAll(t)
  local song = self.song
  if not song then
    return
  end

  for _, aseq in pairs(song.sequencers) do
    aseq:move(t)
  end
end

function lib:trigger(t)
  local last = self.last_t or 0
  local song = self.song
  if not song then
    return
  end

  for _, aseq in pairs(song.sequencers) do
    -- Loop through all sequencers
    aseq:step(t)
  end

  if t >= last + 12 or t < last then
    self.last_t = t
    local anim = self.animate
    if anim then
      anim(self, t)
    end
  end
end

function lib:stop()
  local song = self.song
  if not song then
    return
  end

  for _, aseq in pairs(song.sequencers) do
    -- Loop through all sequencers
    aseq:allOff()
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

-- This is called when we are running without a scheduler.
function lib:pull()
  local pad, midiin = self.pad, self.midiin
  if pad    then pad.lin:pull() end
  if midiin then midiin:pull()  end
end

function lib:backup()
  local song = self.song
  local view_name = self.view and self.view.name or 'Home'
  local key = self.view and self.view.key
  local pattern
  if song and song.edit_pattern then
    pattern = song.edit_pattern.posid
  end
  self.db:setGlobals {
    song = song and song.posid or 1,
    view = view_name,
    key  = key,
    pattern = pattern,
  }
  return self.db:backup()
end

function lib:restore(data)
  self.db:restore(data)
  local globals = self.db:getGlobals()
  self.song = nil
  if globals.song then
    self:loadSong(globals.song)
    if globals.pattern then
      song.edit_pattern = song:getOrCreatePattern(globals.pattern)
    end
  end
  self:loadView(globals.view or 'Home', globals.key)
end

-- Connect sequencer to Launchpad, midi inputs and outputs.
function lib:connect()
  if not self.pad then
    -- Try to connect to Launchpad
    self.pad = binseq.Launchpad(self.pad_name)
  end

  --=============================================== Setup midi Out
  if not self.midiout then
    -- Try to connect to midi Out
    local ok = pcall(function()
      if self.out_name then
        self.midiout = midi.Out(self.out_name)
      else
        self.midiout = midi.Out()
        self.midiout:virtualPort('LSeq')
      end
    end)
    if ok then
      local midiout, send = self.midiout, self.midiout.send
      function self.playback(aseq, e, b, c)
        local skip_schedule = false
        -- Playback function
        -- Important to trigger so that NoteOff is registered.
        if c then
          -- raw midi data (e == first byte)
          send(midiout, e, b, c)
        else
          send(midiout, e:trigger(aseq.channel))
          if e.etype == 'pat_changer' then
            local pat = e.pat.song.patterns[e.note]
            local v = self.song.views.Pattern
            if v then
              if pat then
                v:enablePattern(pat)
              end
              -- Disable self
              v:disablePattern(e.pat)
              skip_schedule = true
            end
          end
          local view = self.view
          local f = view.setEventState
          if f then
            f(view, e)
          end
          return skip_schedule
        end
      end
    end
  end

  --=============================================== Setup midi In
  if not self.midiin and self.in_name ~= false then
    -- in_name == false: Do not use midiin (we manage midi input events in another way).
    -- Try to connect midi In
    pcall(function()
      local midiin
      if self.in_name then
        midiin = midi.In(self.in_name)
      else
        midiin = midi.In()
        midiin:virtualPort('LSeq')
      end

      if midiin then
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
            --self:record(msg)
          end
        end

      end
    end)
  end

  if self.pad and self.midiout and (self.in_name == false or self.midiin) then
    self.connected = true
  end

  if self.connected then
    self:loadView('Home', '   !0 * %50!0 %  4#__P')
  elseif self.pad then
    -- Draw error message (a red cross).
    local pad = self.pad
    pad:clear()
    for i=1,8 do
      pad:button(i,i):setState('Red')
      pad:button(9-i,i):setState('Red')
    end
  end
  
  return self.connected
end
--=============================================== TOP BUTTONS
-- Select song
top_button[POS.SONG] = function(self, row, col)
  self:loadView('Songs')
end

-- Extra
top_button[POS.EXTRA] = function(self, row, col)
  if self.view then
    self:loadView(self.view.name, nil, 'extra')
  end
end

-- Show mixer
top_button[POS.MIXER] = function(self, row, col)
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
