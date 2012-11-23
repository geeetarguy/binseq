--[[------------------------------------------------------

  seq.Event
  ---------

  A pattern is made of many events. An event contains
  the following information:

    * type (note, ctrl, etc). Only notes for the moment.
    * position (position in pattern in midi clock values)
    * note (note value in midi)
    * loop (loop length for this event)
    * length (note duration)
    * velocity (note velocity)

--]]------------------------------------------------------
local lib = {type = 'seq.Event'}
lib.__index     = lib
seq.Event       = lib
local private   = {}
local COPY_KEYS = {'position', 'loop', 'note', 'length', 'velocity', 'mute'}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Event(...)
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
  }
  setmetatable(self, lib)
  if def then
    self:set(def)
  end
  return self
end

-- The event becomes active inside a Sequencer.
function lib:setSequencer(aseq)
  if self.seq then
    -- Remove from previous sequencer
    if self.off_t then
      -- play note Off
      self.seq:trigger(self, true)
    end
    self.seq:removeEvent(self)
  end
  self.seq = aseq
  if aseq 
    and self.mute ~= 1 
    and not self.is_chord then
    aseq:reSchedule(self)
  end
end

-- Returns true if the event timing info changed (needs reschedule).
function lib:set(def)
  local need_schedule = false
  if def.type == 'seq.Event' then
    -- copy
    need_schedule = true
    for _, key in ipairs(COPY_KEYS) do
      self[key] = def[key]
    end
    self.mute = 1
  else
    for key, value in pairs(def) do
      if key == 'length' then
        if self.off_t then
          self.off_t = self.off_t - self.length + value
        end
        need_schedule = true
      elseif not need_schedule and key == 'position' or key == 'loop' or key == 'mute' or key == 'ctrl' then
        need_schedule = true
      end
      self[key] = value
    end
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
function lib:nextTrigger(t, Gs, Gm, not_now)
  -- FIXME If we are between NoteOn and NoteOff: trigger now (not for ChordChanger)
  local m = Gm or self.loop
  local p = self.position - Gs
  -- off_t is off time (set during NoteOn trigger)
  local off_t = self.off_t
  if t == self.allow_now_t then
    not_now = false
    self.allow_now_t = nil
  end

  if p < 0 or p >= m then
    -- Out of current loop region: ignore or trigger NoteOff
    self.t = off_t
    return off_t
  end
  
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
  if self.off_t then
    --=============================================== NoteOff
    local base = chan - 1 + 0x80
    local velo = self.velocity
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
      local velo = self.velocity

      if self.chord_player then
        -- Chord
        local chord = self.pat:chord(self.t)
        if not chord then
          -- Nothing to play...
          self.off_t = nil
          return nil
        end
        local chord_notes = chord.notes or {chord.note}
        local notes = {}
        for _, n in ipairs(chord_notes) do
          table.insert(notes, {base, n, velo})
        end
        -- Make sure the NoteOff message uses the same note value
        self.off_n = notes
        return notes
      else
        -- Single note
        -- Make sure the NoteOff message uses the same note value
        self.off_n = self.note
        return base, self.note, self.velocity
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
function lib.posidToGrid(posid, page, rows_per_page)
  local posid = posid - 1
  local rows_per_page = rows_per_page or 8
  local col = posid % 8
  local row = math.floor(posid / 8) - page * rows_per_page
  if row >= 0 and row < rows_per_page then
    return row + 1, col + 1
  else
    return nil
  end
end

-- Return the posid from (1 based) row and column.
function lib.gridToPosid(row, col, page, rows_per_page)
  local rows_per_page = rows_per_page or 3
  return (page*rows_per_page + row - 1)*8 + col
end

function lib:save()
  -- Write event in database
  local db = self.db
  assert(db, 'Cannot save event without database')
  db:setEvent(self)
end

function lib:delete()
  -- FIXME: make sure event removed from sequencer and pattern...
  local db = self.db
  assert(db, 'Cannot delete event without database')
  db:deleteEvent(self)
  self.deleted = true
end

function private:computeType()
  local pat = self.pat
  if not pat then
    -- This happens during object instantiation from DB.
    return
  end

  if self.loop == 0 then
    --=============================================== Chord
    if not self.is_chord then
      -- add in pattern chords
      local list = pat.chords
      list._len = list._len + 1
      table.insert(list, self)
      self.is_chord = true
    end
    -- Do not schedule
    return false
  else
    if self.is_chord then
      -- remove from pattern chords
      local list = pat.chords
      for i, e in ipairs(list) do
        if e == self then
          list._len = list._len - 1
          table.remove(list, i)
          break
        end
      end
      self.is_chord = false
    end

    local remove_from_changers = self.chord_changer

    if self.note == 0 then
      if self.velocity == 0 then
        --=============================================== Chord changer
        if not self.chord_changer then
          -- add to pattern chord changers
          table.insert(pat.chord_changers, self)
          self.chord_changer = true
        end
        return false
      else
        --=============================================== Chord trigger
        -- chord player
        self.chord_player = true
      end
    else
      self.chord_player  = false
    end

    if remove_from_changers then
      self.chord_changer = false
      local list = pat.chord_changers
      for i, e in ipairs(list) do
        if e == self then
          table.remove(list, i)
          break
        end
      end
    end

    --                   This is an error => mute event.
    if self.mute == 1 or self.position >= self.loop then
      return false
    else
      -- Schedule event
      return true
    end
  end
end
