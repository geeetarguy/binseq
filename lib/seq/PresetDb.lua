--[[------------------------------------------------------

  seq.PresetDb
  ------------

  A database containing presets (patterns) and events in
  these patterns.

--]]------------------------------------------------------
local lib = {type = 'seq.PresetDb'}
lib.__index     = lib
seq.PresetDb    = lib
local private   = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.PresetDb(...)
function lib.new(path)
  local is_new
  local self = {}
  if path == ':memory' then
    self.path = nil
    is_new = true
    self.db = sqlite3.open_memory()
  else
    lk.makePath(lk.pathDir(path))
    is_new = not lk.exist(path)
    self.db = sqlite3.open(path)
  end

  setmetatable(self, lib)

  private.prepareDb(self, is_new)

  return self
end

--==========================================================  PARTITIONS

------------------------------------------------------------  CREATE
function lib:createPattern(posid)
  local stmt = self.create_pattern
  local p = seq.Pattern()
  p.posid = posid
  p.db = self
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
  p.id = self.db:last_insert_rowid()
  return p
end

------------------------------------------------------------  READ

function lib:hasPattern(posid)
  local db = self.db
  local stmt = self.read_pattern_by_posid
  stmt:bind_names { posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  return row and true
end

-- Return a pattern from a row, col and page, nil if not found.
function lib:getPattern(posid, skip_events)
  local db = self.db
  local stmt = self.read_pattern_by_posid
  stmt:bind_names { posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  if row then
    -- create Pattern object
    return seq.Pattern {
      db       = self,
      id       = row[1],
      posid    = row[2],
      note     = row[3],
      velocity = row[4],
      length   = row[5],
      position = row[6],
      loop     = row[7],
    }
  else
    return nil
  end
end

------------------------------------------------------------  UPDATE

function lib:setPattern(p)
  local db = self.db
  local id = p.id
  assert(id, 'Use createPattern to create new objects')
  local stmt = self.update_pattern
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
end

------------------------------------------------------------  COPY

function lib:copyPattern(base, new_posid)
  if self:hasPattern(new_posid) then
    local p = self:getPattern(new_posid)
    p:delete()
  end
  local p = self:createPattern(new_posid)
  local pattern_id = p.id
  for _, e in ipairs(base.events_list) do
    -- copy events
    local ne = self:createEvent(e.posid, pattern_id)
    ne:set(e)
  end
end

------------------------------------------------------------  DELETE

function lib:deletePattern(p)
  local db = self.db
  local id = p.id
  assert(id, 'Cannot delete pattern without id')
  local stmt = self.delete_pattern
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
end

--==========================================================  EVENTS

------------------------------------------------------------  CREATE
function lib:createEvent(posid, pattern_id)
  local stmt = self.create_event
  local e = seq.Event()
  e.posid = posid
  e.pattern_id = pattern_id
  e.db = self
  stmt:bind_names(e)
  stmt:step()
  stmt:reset()
  e.id = self.db:last_insert_rowid()
  return e
end

------------------------------------------------------------  READ

-- Return a pattern from a row, col and page, nil if not found.
function lib:getEvent(posid, pattern_id)
  local db = self.db
  local stmt = self.read_event_by_pattern_id_and_posid
  stmt:bind_names { pattern_id = pattern_id, posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  if row then
    -- create Event object
    return private.eventFromRow(self, row)
  else
    return nil
  end
end

-- Returns an iterator over all the events in the pattern
function lib:getEvents(pattern_id)
  local db = self.db
  local list   = {}
  local events = {}
  local stmt = self.read_events_by_pattern_id
  stmt:bind_names { pattern_id = pattern_id }
  
  -- stmt:rows() is an iterator
  local next_row = stmt:rows()
  return function()
    local row = next_row(stmt)
    if row then
      return private.eventFromRow(self, row)
    else
      -- done
      stmt:reset()
      return nil
    end
  end
end

------------------------------------------------------------  UPDATE

function lib:setEvent(e)
  local db = self.db
  local id = e.id
  assert(id, 'Use createEvent to create new objects')
  local stmt = self.update_event
  stmt:bind_names(e)
  stmt:step()
  stmt:reset()
end

------------------------------------------------------------  DELETE

function lib:deleteEvent(e)
  local db = self.db
  local id = e.id
  assert(id, 'Cannot delete event without id')
  local stmt = self.delete_event
  stmt:bind_names(e)
  stmt:step()
  stmt:reset()
end

--==========================================================  PRIVATE


-- Prepare the database for events
function private:prepareDb(is_new)
  local db = self.db

  -- preset (which pattern on which channel)

  if is_new then
    db:exec [[
      CREATE TABLE presets (id INTEGER PRIMARY KEY);
      CREATE UNIQUE INDEX presets_id_idx ON patterns(id);
      CREATE TABLE presets_patterns (preset_id INTEGER, pattern_id INTEGER);
      CREATE INDEX presets_patterns_preset_id_idx ON presets_patterns(preset_id);
      CREATE INDEX presets_patterns_pattern_id_idx ON presets_patterns(pattern_id);
    ]]
  end


  --==========================================================  PARTITIONS
  -- note, velocity, length, position, loop are global settings
  if is_new then
    db:exec [[
      CREATE TABLE patterns (id INTEGER PRIMARY KEY, posid INTEGER, note REAL, velocity REAL, length REAL, position REAL, loop REAL);
      CREATE UNIQUE INDEX patterns_id_idx ON patterns(id);
    ]]
  end

  ------------------------------------------------------------  CREATE
  self.create_pattern = db:prepare [[
    INSERT INTO patterns VALUES (NULL, :posid, :note, :velocity, :length, :position, :loop);
  ]]

  ------------------------------------------------------------  READ
  self.read_pattern_by_id = db:prepare [[
    SELECT * FROM patterns WHERE id = :id;
  ]]

  self.read_pattern_by_posid = db:prepare [[
    SELECT * FROM patterns WHERE posid = :posid;
  ]]

  ------------------------------------------------------------  UPDATE
  self.update_pattern = db:prepare [[
    UPDATE patterns SET posid = :posid, note = :note, velocity = :velocity, length = :length, position = :position, loop = :loop WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_pattern = db:prepare [[
    DELETE FROM patterns WHERE id = :id;
    DELETE FROM events WHERE pattern_id = :id;
    DELETE FROM presets_patterns WHERE pattern_id = :id;
  ]]

  
  --==========================================================  EVENTS

  -- events table
  if is_new then
    db:exec [[
      CREATE TABLE events (id INTEGER PRIMARY KEY, pattern_id INTEGER, posid INTEGER, note REAL, velocity REAL, length REAL, position REAL, loop REAL, mute INTEGER);
      CREATE UNIQUE INDEX events_id_idx ON events(id);
      CREATE INDEX events_pattern_id_idx ON events(pattern_id);
    ]]
  end

  ------------------------------------------------------------  CREATE
  self.create_event = db:prepare [[
    INSERT INTO events VALUES (NULL, :pattern_id, :posid, :note, :velocity, :length, :position, :loop, :mute);
  ]]

  ------------------------------------------------------------  READ
  self.read_event_by_id = db:prepare [[
    SELECT * FROM events WHERE id = :id;
  ]]

  self.read_event_by_pattern_id_and_posid = db:prepare [[
    SELECT * FROM events WHERE pattern_id = :pattern_id AND posid = :posid;
  ]]

  self.read_events_by_pattern_id = db:prepare [[
    SELECT * FROM events WHERE pattern_id = :pattern_id;
  ]]

  ------------------------------------------------------------  UPDATE
  self.update_event = db:prepare [[
    UPDATE events SET pattern_id = :pattern_id, posid = :posid, note = :note, velocity = :velocity, length = :length, position = :position, loop = :loop, mute = :mute WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_event = db:prepare [[
    DELETE FROM events WHERE id = :id;
  ]]
end



--==========================================================  PRIVATE

function private:eventFromRow(row)
  local e = seq.Event {
    id           = row[1],
    pattern_id = row[2],
    posid        = row[3],
    note         = row[4],
    velocity     = row[5],
    length       = row[6],
    position     = row[7],
    loop         = row[8],
    mute         = row[9],
  }
  -- We only set db now so that 'set' does not save.
  e.db = self
  return e
end

