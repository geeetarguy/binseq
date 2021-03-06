--[[------------------------------------------------------

  binseq.Database
  ---------------

  A database containing presets (patterns) and events in
  these patterns.

  The database should not be used directly (except for the
  Song object). Access sub-objects through their 'parent':

  * Access Pattern through song:[get/create]Pattern(posid)
  * Access Event through patter:[get/create]Event(posid)
  * etc.

--]]------------------------------------------------------
local lib = {type = 'binseq.Database'}
lib.__index     = lib
binseq.Database    = lib
local private   = {}
local DONE      = sqlite3.DONE
math.randomseed(os.time())

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- binseq.Database(...)
function lib.new(path)
  local is_new
  local self = {}
  if path == ':memory:' then
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

function lib:backup()
  return self.db:backup()
end

function lib:restore(data)
  self.db:restore(data)
  private.migrate(self)
end
--==========================================================  GLOBAL

function lib:setGlobals(data)
  local stmt = self.update_globals
  stmt:bind_names {
    data = yaml.dump(data)
  }
  stmt:step()
  stmt:reset()
end

function lib:getGlobals()
  local stmt = self.read_globals
  local row = stmt:first_row()
  stmt:reset()
  return yaml.load(row[1])
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
  local p = binseq.Song {posid = posid, name = name or ''}
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
    return private.songFromRow(self, row)
  else
    return nil
  end
end

-- Returns an iterator over all the songs.
function lib:getSongs()
  local db = self.db
  local stmt = self.read_songs_list
  
  -- stmt:rows() is an iterator
  local next_row = stmt:rows()
  return function()
    local row = next_row(stmt)
    if row then
      return private.songFromRow(self, row)
    else
      -- done
      stmt:reset()
    end
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
  p = binseq.Pattern {
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
  p.data = yaml.dump(p:dataTable())
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
  local p = binseq.Sequencer {
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
  s.data = yaml.dump {
    note     = s.note,
    velocity = s.velocity,
    length   = s.length,
    position = s.position,
    loop     = s.loop,
    channel  = s.channel,
  }
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
  local e = binseq.Event {
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
  e.data = yaml.dump(e:dataTable())
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

lib.MIGRATIONS = {
  {name = 'base', 
   sql  = [[
      /* Events table */
      CREATE TABLE events (id INTEGER PRIMARY KEY, pattern_id INTEGER, posid INTEGER, data TEXT);
      CREATE UNIQUE INDEX events_idx ON events(id);
      CREATE INDEX events_pattern_posidx ON events(pattern_id, posid);
      CREATE INDEX events_pattern_idx ON events(pattern_id);

      /* Pattern */
      CREATE TABLE patterns (id INTEGER PRIMARY KEY, song_id INTEGER, sequencer_id INTEGER, posid INTEGER, data TEXT);
      CREATE UNIQUE INDEX patterns_idx    ON patterns(id);
      CREATE INDEX patterns_song_idx      ON patterns(song_id);
      CREATE INDEX patterns_song_posidx ON patterns(posid, song_id);
      
      /* Sequencer */
      CREATE TABLE sequencers (id INTEGER PRIMARY KEY, song_id INTEGER, posid INTEGER, data TEXT);
      CREATE UNIQUE INDEX sequencers_idx ON sequencers(id);
      CREATE UNIQUE INDEX sequencers_song_posidx ON sequencers(song_id, id);
      
      /* Song */
      CREATE TABLE songs (id INTEGER PRIMARY KEY, posid INTEGER, name TEXT, created_at TEXT);
      CREATE UNIQUE INDEX songs_idx ON songs(id);
      CREATE UNIQUE INDEX songs_posidx ON songs(posid);
   ]]},
  {name = 'globals', 
   sql  = [[
      /* Globals table */
      CREATE TABLE global (id INTEGER PRIMARY KEY, data TEXT);
      INSERT INTO global VALUES (null, "{}");
   ]]},
  {name = '16chan', 
   fun  = function(self)
     local gridToPosid   = binseq.Event.gridToPosid 
     local posidToGrid   = binseq.Event.posidToGrid

     local stmt = self.db:prepare "SELECT * FROM patterns;"
     local updt = self.db:prepare "UPDATE patterns SET posid = :posid WHERE id = :id;"

     for r in stmt:rows() do
       local pat = private.patternFromRow(self, r)
       local row, col = posidToGrid(pat.posid, 0, 8, 8)
       local posid = gridToPosid(row, col, 0, 8, 16)
       updt:bind_names {
         id    = pat.id,
         posid = posid,
       }
       updt:step()
       updt:reset()
     end
     stmt:reset()
   end,
  },
}

-- Prepare the database for events
function private:prepareDb(is_new)
  local db = self.db

  if is_new then
    db:exec [[
      CREATE TABLE schema_info (id INTEGER PRIMARY KEY, data TEXT);
      INSERT INTO schema_info VALUES (null, "{}");
    ]]
  end

  self.read_schema_info = db:prepare [[
    SELECT * FROM schema_info WHERE id = 1;
  ]]

  self.update_schema_info = db:prepare [[
    UPDATE schema_info SET data = :data WHERE id = 1;
  ]]

  private.migrate(self)
  
  --==========================================================  Events

  ------------------------------------------------------------  CREATE
  self.create_event = db:prepare [[
    INSERT INTO events VALUES (NULL, :pattern_id, :posid, :data);
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
    UPDATE events SET pattern_id = :pattern_id, posid = :posid, data = :data WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_event = db:prepare [[
    DELETE FROM events WHERE id = :id;
  ]]

  --==========================================================  Pattern

  ------------------------------------------------------------  CREATE
  self.create_pattern = db:prepare [[
    INSERT INTO patterns VALUES (NULL, :song_id, :sequencer_id, :posid, :data);
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

  self.all_patterns = db:prepare [[
    SELECT * FROM patterns;
  ]]

  ------------------------------------------------------------  UPDATE
  self.update_pattern = db:prepare [[
    UPDATE patterns SET song_id = :song_id, sequencer_id = :sequencer_id, posid = :posid, data =:data WHERE id = :id;
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

  ------------------------------------------------------------  CREATE
  self.create_sequencer = db:prepare [[
    INSERT INTO sequencers VALUES (NULL, :song_id, :posid, :data);
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
    UPDATE sequencers SET song_id = :song_id, posid = :posid, data = :data WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_sequencer = {
    db:prepare 'DELETE FROM sequencers          WHERE id = :id;',
    db:prepare 'UPDATE patterns SET sequencer_id = NULL WHERE sequencer_id = :id;',
    nil, -- avoid second argument from db:prepare
  }

  --==========================================================  Song
  -- note, velocity, length, position, loop are global settings

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

  self.read_songs_list = db:prepare [[
    SELECT * FROM songs ORDER BY posid ASC;
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

  --==========================================================  Global
  ------------------------------------------------------------  READ
  self.read_globals = db:prepare [[
    SELECT data FROM global WHERE id = 1;
  ]]
  ------------------------------------------------------------  UPDATE
  self.update_globals = db:prepare [[
    UPDATE global SET data = :data WHERE id = 1;
  ]]
end

--==========================================================  PRIVATE

function private:patternFromRow(row)
  local data = row[5]
  if data then
    row.data = nil
    data = yaml.load(data) or {}
  else
    data = {}
  end
  local p = binseq.Pattern {
    id           = row[1],
    song_id      = row[2],
    sequencer_id = row[3],
    posid        = row[4],
    data         = data,
  }
  -- We only set db now so that 'set' does not save.
  p.db = self
  return p
end

function private:eventFromRow(row)
  local data = row[4]
  if data then
    row.data = nil
    data = yaml.load(data) or {}
  else
    data = {}
  end
  local e = binseq.Event {
    id           = row[1],
    pattern_id   = row[2],
    posid        = row[3],
  }
  -- TODO data fields are copied 3 times (yaml.load, here, and in Event:set).
  e:set(data)

  -- We only set db now so that 'set' does not save.
  e.db = self
  return e
end

function private:sequencerFromRow(row)
  local data = row[4]
  if data then
    row.data = nil
    data = yaml.load(data) or {}
  else
    data = {}
  end
  local s = binseq.Sequencer {
    id       = row[1],
    song_id  = row[2],
    posid    = row[3],
    -- TODO data fields are copied 3 times (yaml.load, here, and in Sequecer:set).
    channel  = data.channel,
  }
  -- We only set db now so that 'set' does not save.
  s.db = self
  return s
end

function private:getOrCreateSchemaInfo()
  local db = self.db
  local stmt = self.read_schema_info
  local row = stmt:first_row()
  stmt:reset()
  if not row then
    db:exec [[ INSERT INTO schema_info VALUES (1, "{}"); ]]
    row = stmt:first_row()
    stmt:reset()
  end
  return yaml.load(row[2])
end

function private:saveSchemaInfo()
  local stmt = self.update_schema_info
  stmt:bind_names {
    data = yaml.dump(self.schema_info)
  }
  stmt:step()
  stmt:reset()
end

function private:migrate()
  local schema_info = private.getOrCreateSchemaInfo(self)
  self.schema_info = schema_info

  local done = {}
  local db = self.db
  db:exec 'BEGIN'
  for _, m in ipairs(lib.MIGRATIONS) do
    if not schema_info[m.name] then
      if m.sql then
        db:exec(m.sql)
      elseif m.fun then
        m.fun(self)
      end
      done[m.name] = true
    end
  end
  db:exec 'COMMIT;'

  for k, v in pairs(done) do
    schema_info[k] = v
  end
  private.saveSchemaInfo(self)
end

function private:songFromRow(row)
  return binseq.Song {
    db       = self,
    id       = row[1],
    posid    = row[2],
    name     = row[3],
  }
end
