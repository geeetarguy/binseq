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
lib.__index      = lib
seq.Event    = lib
local private    = {}
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
  if aseq and self.mute ~= 1 then
    aseq:schedule(self)
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
      elseif not need_schedule and key == 'position' or key == 'loop' or key == 'mute' then
        need_schedule = true
      end
      self[key] = value
    end
  end

  if self.db then
    self:save()
  end

  if need_schedule then
    local aseq = self.seq
    if aseq then
      aseq:schedule(self)
    end
  end
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
  
  local tl = t % m
  local te = p - tl
  if te < 0 or (not_now and te == 0) then
    -- Wrap around loop
    te = te + m
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
function lib:trigger(chan)
  local chan = chan or 1
  if self.off_t then
    -- NoteOff
    self.off_t = nil
    return chan - 1 + 0x80, self.off_n, self.velocity
  else
    -- NoteOn
    self.off_t = self.t + self.length
    -- Make sure the NoteOff message uses the same note value
    self.off_n = self.note
    return chan - 1 + 0x90, self.note, self.velocity
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
  local db = self.db
  assert(db, 'Cannot delete event without database')
  db:deleteEvent(self)
  self.deleted = true
end
