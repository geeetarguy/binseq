--[[------------------------------------------------------

  binseq.Event
  ------------

  A pattern is made of many events. An event contains
  the following information:

    * type (note, ctrl, etc). Only notes for the moment.
    * position (position in pattern in midi clock values)
    * note (note value in midi)
    * loop (loop length for this event)
    * length (note duration)
    * velocity (note velocity)

--]]------------------------------------------------------
local lib = {type = 'binseq.Event'}
lib.__index     = lib
binseq.Event       = lib
local private   = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- binseq.Event(...)
function lib.new(def)
  local self = {
    mute     = 1,
    position = 0,
    loop     = 24,
    note     = 0,
    length   = 6,
    velocity = 80,
    -- Stores the currently playing value index (index.length, ...)
    index    = {},
    etype    = 'note',
  }
  setmetatable(self, lib)
  if def then
    self:set(def)
  end
  return self
end

-- The event becomes active inside a Sequencer.
function lib:setSequencer(aseq)
  if self.seq == aseq then return end

  if self.seq then
    -- Remove from previous sequencer
    if self.off_t then
      -- play note Off
      self.seq:trigger(self, true)
    end
    self.seq:removeEvent(self)
  end

  self.seq = aseq
  if aseq and self:scheduledType() then
    aseq:reSchedule(self)
  end
end

function lib:scheduledType()
  local et = self.etype
  --                   This is an error => mute event.
  if self.mute == 1 or
     et == 'chord'  or
     et == 'chord_changer' then
    return false
  else
    -- Schedule event
    return true
  end
end

-- Returns true if the event timing info changed (needs reschedule).
function lib:set(def)
  local need_schedule = false
  for key, value in pairs(def) do
    if key == 'length' then
      if self.off_t then
        self.off_t = self.off_t - self.length + value
      end
      need_schedule = true
    elseif key == 'ctrl' then
      if value == 0 then
        value = nil
      end
      need_schedule = true
    elseif key == 'notes' or key == 'velocities' or key == 'lengths' then
      value._len = #value
    elseif not need_schedule and key == 'position' or key == 'loop' or key == 'mute' then
      need_schedule = true
    end

    self[key] = value
  end

  if self.db then
    self:save()
  end

  local scheduled_type = private.computeType(self)
  local aseq = self.seq
  if not aseq then
    return
  end

  if scheduled_type and need_schedule then
    aseq:reSchedule(self)
  elseif not scheduled_type and self.prev then
    aseq:removeEvent(self)
  end
end

function lib:copy(dump)
  -- These values may not be present in data and would not be overwriten.
  self.index = {}
  self.velocities = nil
  self.lengths = nil
  self.notes = nil
  self.ctrl = nil
  self:set(dump.data)
end

function lib:setPattern(pat)
  assert(not self.pat, "Cannot change pattern")
  self.pat = pat
  private.computeType(self)
end

-- 0      Gs             Ep       Ep (ignored)
-- |-------|-------------x--|-----x
-- |-------|---- m ---------|
-- |-------|- tl -|- te -|        normal trigger
-- |-------|--- p -------|
--
-- |-------|---- tl -------|------------------ te --|      wrap around on next loop
-- |-------|--- p -------|
-- t = time in midi clock since start of song.
function lib:nextTrigger(t, not_now)
  local Gs = 0
  local Gm = 0
  local pat = self.pat
  if pat and self.etype ~= 'pat_changer' then
    Gs = pat.position
    Gm = pat.loop
  end
  -- TODO: If we are between NoteOn and NoteOff: trigger now ? (not for ChordChanger)

  local m = self.loop
  if Gm > 0 and m > Gm then
    m = Gm
  end
  -- off_t is off time (set during NoteOn trigger)
  local off_t = self.off_t
  if t == self.allow_now_t then
    not_now = false
    self.allow_now_t = nil
  end

  local p = (self.position + Gs) % m
  
  local count = math.floor(t / m)
  -- tl = t % m
  local tl = t - count * m
  local te = p - tl
  if te < 0 or (not_now and te == 0) then
    -- Wrap around loop
    te = te + m
    count = count + 1
  end

  if not self.off_t then
    -- Only change on next NoteOn
    local index = self.index
    local notes = self.notes
    if notes then
      local i = 1 + count % notes._len
      index.note = i
      self.note = notes[i]
    end

    local velocities = self.velocities
    if velocities then
      local i = 1 + count % velocities._len
      index.velocity = i
      self.velocity = velocities[i]
    end

    local lengths = self.lengths
    if lengths then
      local i = 1 + count % lengths._len
      index.length = i
      self.length = lengths[i]
    end
  end
  
  -- Return absolute next trigger
  local nt = t + te
  if off_t and off_t < nt then
    self.t = off_t
    return off_t
  else
    -- If off_t == nt, we should not take not_now in consideration on next
    -- run so that the next loop triggers the same nt.
    if off_t == nt then
      self.allow_now_t = nt
    end
    self.t = nt
    return nt
  end
end

-- Return midi event to trigger
local next = next
local WEAK = {__mode="k"}
function lib:trigger(chan)
  local chan = chan or 1

  if self.pat_changer then

    return nil
  end

  local pat = self.pat
  local Gv = 0
  if pat then Gv = pat.velocity end
  local velo = math.min(127,self.velocity + Gv)

  if self.off_t then
    --=============================================== NoteOff
    local base = chan - 1 + 0x80
    self.off_t = nil

    if type(self.off_n) == 'table' then
      -- chord Off
      local off = self.off_n
      for i, n in ipairs(off) do
        -- NoteOn to NoteOff
        n[1] = base
      end
      return off
    elseif self.off_n then
      return base, self.off_n, velo
    end

    -- Ctrl ramp was ON, turn OFF.
    local list = self.off_ctrl
    if list then
      self.off_ctrl = nil
      list[self] = nil
    end
  else
    -- Play Ctrl or Note
    self.off_t = self.t + self.length
    local ctrl = self.ctrl
    if ctrl then
      --=============================================== Ctrl On
      local ctrls = self.seq and self.seq.ctrls

      if ctrls then
        -- Add to control change ramps
        local list = ctrls[ctrl]
        -- Add to ctrls.
        if not list then
          list = setmetatable({}, WEAK)
          ctrls[ctrl] = list
        end
        list[self] = true
        -- In case of reschedule, NoteOff.
        self.off_ctrl = list
      end
    else
      --=============================================== NoteOn
      local base = chan - 1 + 0x90
      local etype = self.etype
      local pat = self.pat
      local note = pat.note

      if etype == 'chord_player' then
        -- Chord
        local chord = pat:chord(self.t)
        if not chord then
          -- Nothing to play...
          self.off_t = nil
          return nil
        end
        local chord_notes = chord.notes or {chord.note}
        local notes = {}
        for _, n in ipairs(chord_notes) do
          table.insert(notes, {base, n + note, velo})
        end
        notes.chord = chord
        -- Make sure the NoteOff message uses the same note value
        self.off_n = notes
        return notes
      elseif etype == 'pat_changer' then
        -- no midi
        return nil
      else
        -- Note
        -- Make sure the NoteOff message uses the same note value
        local n = self.note + note
        self.off_n = n
        return base, n, velo
      end
    end
  end
end

-- Return the posid (1 based) from (1 based) row (display as list)
function lib.rowToPosid(row, page)
  return page * 8 + row
end

-- Return the (1 based) row (display as list) from posid (1 based)
function lib.posidToRow(posid, page)
  local row = posid - page * 8
  if row >= 1 and row <= 8 then
    return row
  else
    return nil
  end
end

-- Return the row and column from posid (1 based)
function lib.posidToGrid(posid, page, rows_per_page, cols_per_row, offset)
  local cols_per_row  = cols_per_row  or 8
  local posid = posid - 1
  local rows_per_page = rows_per_page or 8
  local col = posid % cols_per_row
  local row = math.floor(posid / cols_per_row) - page * rows_per_page
  if row >= 0 and row < rows_per_page then
    return row + 1, col + 1 - (offset or 0)
  else
    return nil
  end
end

-- Return the posid from (1 based) row and column.
function lib.gridToPosid(row, col, page, rows_per_page, cols_per_row, offset)
  local cols_per_row  = cols_per_row  or 8
  local rows_per_page = rows_per_page or 3
  return (page*rows_per_page + row - 1) * cols_per_row + col + (offset or 0)
end

function lib:save()
  -- Write event in database
  local db = self.db
  assert(db, 'Cannot save event without database')
  db:setEvent(self)
end

function lib:dataTable()
  return {
    note     = self.note,
    notes    = self.notes,
    velocity = self.velocity,
    velocities = self.velocities,
    length   = self.length,
    lengths  = self.lengths,
    ctrl     = self.ctrl,
    position = self.position,
    loop     = self.loop,
    mute     = self.mute,
  }
end

function lib:dump()
  return {
    type = self.type,
    data = self:dataTable(),
  }
end

function lib:delete()
  local db = self.db
  assert(db, 'Cannot delete event without database')
  db:deleteEvent(self)
  self.deleted = true
  if self.seq then self:setSequencer(nil) end
  if self.pat then self.pat:removeEvent(self) end
end

function private:computeType()
  local pat = self.pat
  if not pat then
    -- This happens during object instantiation from DB.
    return
  end

  if self.loop == 0 then
    --=============================================== Chord
    if self.etype ~= 'chord' then
      -- add in pattern chords
      pat:addChord(self)
      self.etype = 'chord'
    end
    -- Do not schedule
    return false
  else
    if self.etype == 'chord' then
      -- remove from pattern chords
      pat:removeChord(self)
    end

    local remove_from_changers = self.etype == 'chord_changer'

    if self.ctrl then
      self.etype = 'ctrl'
    elseif self.note == 0 then
      if self.velocity == 0 then
        --=============================================== Chord changer
        if self.etype ~= 'chord_changer' then
          -- add to pattern chord changers
          table.insert(pat.chord_changers, self)
          self.etype = 'chord_changer'
        end
        -- Not scheduled
        return false
      else
        --=============================================== Chord trigger
        -- chord player
        self.etype = 'chord_player'
      end
    elseif self.velocity == 0 then
      self.etype = 'pat_changer'
    else
      self.etype = 'note'
    end

    if remove_from_changers then
      pat:removeFromChangers(self)
    end

    return self:scheduledType()
  end
end
