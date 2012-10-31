--[[------------------------------------------------------

  seq.PresetDb
  ------------

  A database containing presets (patterns) and events in
  these patterns.

  The database should not be used directly (except for the
  Song object). Access sub-objects through their 'parent':

  * Access Pattern through song:[get/create]Pattern(posid)
  * Access Event through patter:[get/create]Event(posid)
  * etc.

--]]------------------------------------------------------
local lib = {type = 'seq.PresetDb'}
lib.__index     = lib
seq.PresetDb    = lib
local private   = {}
local DONE      = sqlite3.DONE
math.randomseed(os.time())

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

--==========================================================  SONGS

------------------------------------------------------------  CREATE
function lib:getOrCreateSong(posid, name)
  local s = self:getSong(posid)
  if s then
    if s.name ~= name then
      s:set {name = name}
    end
    return s
  end

  local stmt = self.create_song
  local p = seq.Song {posid = posid, name = name or ''}
  p.posid = posid
  p.db = self
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
  p.id = self.db:last_insert_rowid()
  return p
end

------------------------------------------------------------  READ

function lib:hasSong(posid)
  local db = self.db
  local stmt = self.read_song_by_posid
  stmt:bind_names { posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  return row and true
end

function lib:getSong(posid)
  local db = self.db
  local stmt = self.read_song_by_posid
  stmt:bind_names { posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  if row then
    -- create Song object
    return seq.Song {
      db       = self,
      id       = row[1],
      posid    = row[2],
      name     = row[3],
    }
  else
    return nil
  end
end

------------------------------------------------------------  UPDATE

function lib:setSong(s)
  assert(s.id, 'Use createSong to create new objects')
  local stmt = self.update_song
  stmt:bind_names(s)
  stmt:step()
  stmt:reset()
end

------------------------------------------------------------  COPY

function lib:copySong(base, new_posid)
  if self:hasSong(new_posid) then
    local p = self:getSong(new_posid)
    p:delete()
  end
  assert(false, 'TODO')
  local p = self:createSong(new_posid)
  local pattern_id = p.id
  for _, e in ipairs(base.events_list) do
    -- copy events
    local ne = self:createEvent(e.posid, pattern_id)
    ne:set(e)
  end
end

------------------------------------------------------------  DELETE

function lib:deleteSong(s)
  assert(s.id, 'Cannot delete song without id')
  local db = self.db
  db:exec 'BEGIN'
  for _, stmt in ipairs(self.delete_song) do
    stmt:bind_names(s)
    stmt:step()
    stmt:reset()
  end
  db:exec 'COMMIT;'
end

--==========================================================  PATTERNS

------------------------------------------------------------  CREATE
function lib:getOrCreatePattern(posid, song_id)
  local p = self:getPattern(posid, song_id)
  if p then
    return p
  end

  local stmt = self.create_pattern
  p = seq.Pattern {
    song_id = song_id,
    posid   = posid
  }
  p.db = self
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
  p.id = self.db:last_insert_rowid()
  return p
end

------------------------------------------------------------  READ

function lib:hasPattern(posid, song_id)
  local db = self.db
  local stmt = self.read_pattern_by_posid
  stmt:bind_names { song_id = song_id, posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  return row and true
end

function lib:getPattern(posid, song_id)
  local db = self.db
  local stmt = self.read_pattern_by_posid
  stmt:bind_names { song_id = song_id, posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  if row then
    -- create Pattern object
    return private.patternFromRow(self, row)
  end
end

-- Returns an iterator over all the events in the pattern
function lib:getPatterns(song_id)
  local db = self.db
  local stmt = self.read_patterns_by_song_id
  stmt:bind_names { song_id = song_id }
  
  -- stmt:rows() is an iterator
  local next_row = stmt:rows()
  return function()
    local row = next_row(stmt)
    if row then
      return private.patternFromRow(self, row)
    else
      -- done
      stmt:reset()
      return nil
    end
  end
end

------------------------------------------------------------  UPDATE

function lib:setPattern(p)
  assert(p.id, 'Use createPattern to create new objects')
  local stmt = self.update_pattern
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
end

------------------------------------------------------------  COPY

function lib:copyPattern(base, new_posid, song_id)
  if self:hasPattern(new_posid) then
    local p = self:getPattern(new_posid, song_id)
    p:delete()
  end
  local p = self:createPattern(new_posid, song_id)
  local pattern_id = p.id
  for _, e in ipairs(base.events_list) do
    -- copy events
    local ne = self:createEvent(e.posid, pattern_id)
    ne:set(e)
  end
end

------------------------------------------------------------  DELETE

function lib:deletePattern(p)
  assert(p.id, 'Cannot delete pattern without id')
  local db = self.db
  db:exec 'BEGIN'
  for _, stmt in ipairs(self.delete_pattern) do
    stmt:bind_names(p)
    stmt:step()
    stmt:reset()
  end
  db:exec 'COMMIT'
end


--==========================================================  SEQUENCERS

------------------------------------------------------------  CREATE
function lib:getOrCreateSequencer(posid, song_id)
  local s = self:getSequencer(posid, song_id)
  if s then
    return s
  end

  local stmt = self.create_sequencer
  local p = seq.Sequencer {
    posid   = posid,
    song_id = song_id,
  }
  p.db = self
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
  p.id = self.db:last_insert_rowid()
  return p
end

function lib:activatePattern(pattern_id, sequencer_id)
  -- not needed.
  -- self:deactivatePattern(pattern_id, sequencer_id)
  assert(not self:activePattern(pattern_id, sequencer_id))
  local stmt = self.create_sequencer_pattern
  stmt:bind_names { pattern_id = pattern_id, sequencer_id = sequencer_id }
  stmt:step()
  stmt:reset()
end

function lib:deactivatePattern(pattern_id, sequencer_id)
  local stmt = self.delete_sequencer_pattern
  stmt:bind_names { pattern_id = pattern_id, sequencer_id = sequencer_id }
  stmt:step()
  stmt:reset()
end

function lib:activePattern(pattern_id, sequencer_id)
  local stmt = self.read_sequencers_patterns
  stmt:bind_names { pattern_id = pattern_id, sequencer_id = sequencer_id }
  local row = stmt:first_row()
  stmt:reset()
  return row and true
end
------------------------------------------------------------  READ

function lib:hasSequencer(posid)
  local db = self.db
  local stmt = self.read_sequencer_by_posid
  stmt:bind_names { posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  return row and true
end

function lib:getSequencer(posid, song_id)
  local db = self.db
  local stmt = self.read_sequencer_by_posid
  stmt:bind_names { posid = posid, song_id = song_id }
  local row = stmt:first_row()
  stmt:reset()
  if row then
    -- create Sequencer object
    return private.sequencerFromRow(self, row)
  end
end

-- Returns an iterator over all the sequencers in the song
function lib:getSequencers(song_id)
  local db = self.db
  local stmt = self.read_sequencers_by_song_id
  stmt:bind_names { song_id = song_id }
  
  -- stmt:rows() is an iterator
  local next_row = stmt:rows()
  return function()
    local row = next_row(stmt)
    if row then
      return private.sequencerFromRow(self, row)
    else
      -- done
      stmt:reset()
    end
  end
end

-- Returns an iterator over all the active patterns in the sequencer
function lib:getActivePatternPosids(sequencer_id)
  local db = self.db
  local stmt = self.read_pattern_posid_by_sequencer_id
  stmt:bind_names { sequencer_id = sequencer_id }
  
  -- stmt:rows() is an iterator
  local next_row = stmt:rows()
  return function()
    local row = next_row(stmt)
    if row then
      return row[1]
    else
      -- done
      stmt:reset()
    end
  end
end

------------------------------------------------------------  UPDATE

function lib:setSequencer(s)
  assert(s.id, 'Use createSequencer to create new objects')
  local stmt = self.update_sequencer
  stmt:bind_names(s)
  stmt:step()
  stmt:reset()
end

------------------------------------------------------------  COPY

function lib:copySequencer(base, new_posid, song_id)
  if self:hasSequencer(new_posid) then
    local p = self:getSequencer(new_posid, song_id)
    p:delete()
  end
  local p = self:createSequencer(new_posid, song_id)
  local pattern_id = p.id
  for _, e in ipairs(base.events_list) do
    -- copy events
    local ne = self:createEvent(e.posid, pattern_id)
    ne:set(e)
  end
end

------------------------------------------------------------  DELETE

function lib:deleteSequencer(p)
  assert(p.id, 'Cannot delete sequencer without id')
  local db = self.db
  for _, stmt in ipairs(self.delete_sequencer) do
    stmt:bind_names(p)
    stmt:step()
    stmt:reset()
  end
end

--==========================================================  EVENTS

------------------------------------------------------------  CREATE
function lib:getOrCreateEvent(posid, pattern_id)
  local e = self:getEvent(posid, pattern_id)
  if e then
    return e
  end

  local stmt = self.create_event
  local e = seq.Event {
    posid = posid,
    pattern_id = pattern_id,
  }
  e.db = self
  stmt:bind_names(e)
  stmt:step()
  stmt:reset()
  e.id = self.db:last_insert_rowid()
  return e
end


------------------------------------------------------------  READ

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
  assert(e.id, 'Use createEvent to create new objects')
  local stmt = self.update_event
  stmt:bind_names(e)
  stmt:step()
  stmt:reset()
end

------------------------------------------------------------  DELETE

function lib:deleteEvent(e)
  assert(e.id, 'Cannot delete event without id')
  local stmt = self.delete_event
  stmt:bind_names(e)
  stmt:step()
  stmt:reset()
end

--==========================================================  PRIVATE


-- Prepare the database for events
function private:prepareDb(is_new)
  local db = self.db

  --==========================================================  Events

  -- events table
  if is_new then
    db:exec [[
      CREATE TABLE events (id INTEGER PRIMARY KEY, pattern_id INTEGER, posid INTEGER, note REAL, velocity REAL, length REAL, position REAL, loop REAL, mute INTEGER);
      CREATE UNIQUE INDEX events_idx ON events(id);
      CREATE INDEX events_pattern_posidx ON events(pattern_id, posid);
      CREATE INDEX events_pattern_idx ON events(pattern_id);
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

  --==========================================================  Pattern
  if is_new then
    db:exec [[
      CREATE TABLE patterns (id INTEGER PRIMARY KEY, song_id INTEGER, sequencer_id INTEGER, posid INTEGER);
      CREATE UNIQUE INDEX patterns_idx    ON patterns(id);
      CREATE INDEX patterns_song_idx      ON patterns(song_id);
      CREATE INDEX patterns_song_posidx ON patterns(posid, song_id);
    ]]
  end

  ------------------------------------------------------------  CREATE
  self.create_pattern = db:prepare [[
    INSERT INTO patterns VALUES (NULL, :sequencer_id, :song_id, :posid);
  ]]

  ------------------------------------------------------------  READ
  self.read_pattern_by_id = db:prepare [[
    SELECT * FROM patterns WHERE id = :id;
  ]]

  self.read_pattern_by_posid = db:prepare [[
    SELECT * FROM patterns WHERE song_id = :song_id AND posid = :posid;
  ]]

  self.read_patterns_by_song_id = db:prepare [[
    SELECT * FROM patterns WHERE song_id = :song_id;
  ]]

  ------------------------------------------------------------  UPDATE
  self.update_pattern = db:prepare [[
    UPDATE patterns SET song_id = :song_id, sequencer_id = :sequencer_id, posid = :posid WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_pattern = {
    db:prepare 'DELETE FROM patterns WHERE id = :id;',
    db:prepare 'DELETE FROM events WHERE pattern_id = :id;',
    nil -- avoid second argument from db:prepare
  }
  
  --==========================================================  Sequencer
  -- note, velocity, length, position, loop are global settings
  -- * list of active patterns
  -- * global settings
  --   => note, velocity, length, position, loop
  --   => channel, mute, pattern mode (single, multiple, latch)
  if is_new then
    db:exec [[
      CREATE TABLE sequencers (id INTEGER PRIMARY KEY, song_id INTEGER, posid INTEGER, note REAL, velocity REAL, length REAL, position REAL, loop REAL, channel INTEGER);
      CREATE UNIQUE INDEX sequencers_idx ON sequencers(id);
      CREATE UNIQUE INDEX sequencers_song_posidx ON sequencers(song_id, id);
    ]]
  end

  ------------------------------------------------------------  CREATE
  self.create_sequencer = db:prepare [[
    INSERT INTO sequencers VALUES (NULL, :song_id, :posid, :note, :velocity, :length, :position, :loop, :channel);
  ]]

  ------------------------------------------------------------  READ
  self.read_sequencer_by_id = db:prepare [[
    SELECT * FROM sequencers WHERE id = :id;
  ]]

  self.read_sequencer_by_posid = db:prepare [[
    SELECT * FROM sequencers WHERE posid = :posid AND song_id = :song_id;
  ]]

  self.read_sequencers_by_song_id = db:prepare [[
    SELECT * FROM sequencers WHERE song_id = :song_id;
  ]]

  self.read_pattern_posid_by_sequencer_id = db:prepare [[
    SELECT posid FROM patterns WHERE sequencer_id = :sequencer_id;
  ]]

  ------------------------------------------------------------  UPDATE
  self.update_sequencer = db:prepare [[
    UPDATE sequencers SET song_id = :song_id, posid = :posid, note = :note, velocity = :velocity, length = :length, position = :position, loop = :loop, channel = :channel WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_sequencer = {
    db:prepare 'DELETE FROM sequencers          WHERE id = :id;',
    db:prepare 'UPDATE patterns SET sequencer_id = NULL WHERE sequencer_id = :id;',
    nil, -- avoid second argument from db:prepare
  }

  --==========================================================  Song
  -- note, velocity, length, position, loop are global settings
  if is_new then
    db:exec [[
      CREATE TABLE songs (id INTEGER PRIMARY KEY, posid INTEGER, name TEXT, created_at TEXT);
      CREATE UNIQUE INDEX songs_idx ON songs(id);
      CREATE UNIQUE INDEX songs_posidx ON songs(posid);
    ]]
  end

  ------------------------------------------------------------  CREATE
  self.create_song = db:prepare [[
    INSERT INTO songs VALUES (NULL, :posid, :name, :created_at);
  ]]

  ------------------------------------------------------------  READ
  self.read_song_by_id = db:prepare [[
    SELECT * FROM songs WHERE id = :id;
  ]]

  self.read_song_by_posid = db:prepare [[
    SELECT * FROM songs WHERE posid = :posid;
  ]]

  ------------------------------------------------------------  UPDATE
  self.update_song = db:prepare [[
    UPDATE songs SET posid = :posid, name = :name, created_at = :created_at WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_song = {
    db:prepare 'DELETE FROM events WHERE pattern_id = (SELECT id FROM patterns WHERE song_id = :id);',
    db:prepare 'DELETE FROM patterns WHERE song_id = :id;',
    db:prepare 'DELETE FROM sequencers WHERE song_id = :id;',
    db:prepare 'DELETE FROM songs WHERE id = :id;',
    nil, -- to avoid second argument from db:prepare
  }
end

--==========================================================  PRIVATE

function private:patternFromRow(row)
  local p = seq.Pattern {
    id           = row[1],
    song_id      = row[2],
    sequencer_id = row[2],
    posid        = row[3],
  }
  -- We only set db now so that 'set' does not save.
  p.db = self
  return p
end

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

function private:sequencerFromRow(row)
  local s = seq.Sequencer {
    id       = row[1],
    song_id  = row[2],
    posid    = row[3],
    note     = row[4],
    velocity = row[5],
    length   = row[6],
    position = row[7],
    loop     = row[8],
    channel  = row[9],
  }
  -- We only set db now so that 'set' does not save.
  s.db = self
  return s
end
