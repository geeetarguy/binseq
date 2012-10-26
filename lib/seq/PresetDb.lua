--[[------------------------------------------------------

  seq.PresetDb
  ------------

  A database containing presets (partitions) and events in
  these partitions.

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
function lib:createPartition(posid)
  local stmt = self.create_partition
  local p = seq.Partition()
  p.posid = posid
  p.db = self
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
  p.id = self.db:last_insert_rowid()
  return p
end

------------------------------------------------------------  READ

function lib:hasPartition(posid)
  local db = self.db
  local stmt = self.read_partition_by_posid
  stmt:bind_names { posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  return row and true
end

-- Return a partition from a row, col and page, nil if not found.
function lib:getPartition(posid, skip_events)
  local db = self.db
  local stmt = self.read_partition_by_posid
  stmt:bind_names { posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  if row then
    -- create Partition object
    return seq.Partition {
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

function lib:setPartition(p)
  local db = self.db
  local id = p.id
  assert(id, 'Use createPartition to create new objects')
  local stmt = self.update_partition
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
end

------------------------------------------------------------  DELETE

function lib:deletePartition(p)
  local db = self.db
  local id = p.id
  assert(id, 'Cannot delete partition without id')
  local stmt = self.delete_partition
  stmt:bind_names(p)
  stmt:step()
  stmt:reset()
end

--==========================================================  EVENTS

------------------------------------------------------------  CREATE
function lib:createEvent(posid, partition_id)
  local stmt = self.create_event
  local e = seq.Event()
  e.posid = posid
  e.partition_id = partition_id
  e.db = self
  stmt:bind_names(e)
  stmt:step()
  stmt:reset()
  e.id = self.db:last_insert_rowid()
  return e
end

------------------------------------------------------------  READ

-- Return a partition from a row, col and page, nil if not found.
function lib:getEvent(posid, partition_id)
  local db = self.db
  local stmt = self.read_event_by_partition_id_and_posid
  stmt:bind_names { partition_id = partition_id, posid = posid }
  local row = stmt:first_row()
  stmt:reset()
  if row then
    -- create Event object
    return private.eventFromRow(self, row)
  else
    return nil
  end
end

-- Returns an iterator over all the events in the partition
function lib:getEvents(partition_id)
  local db = self.db
  local list   = {}
  local events = {}
  local stmt = self.read_events_by_partition_id
  stmt:bind_names { partition_id = partition_id }
  
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

  -- preset (which partition on which channel)

  if is_new then
    db:exec [[
      CREATE TABLE presets (id INTEGER PRIMARY KEY);
      CREATE UNIQUE INDEX presets_id_idx ON partitions(id);
      CREATE TABLE presets_partitions (preset_id INTEGER, partition_id INTEGER);
      CREATE INDEX presets_partitions_preset_id_idx ON presets_partitions(preset_id);
      CREATE INDEX presets_partitions_partition_id_idx ON presets_partitions(partition_id);
    ]]
  end


  --==========================================================  PARTITIONS
  -- note, velocity, length, position, loop are global settings
  if is_new then
    db:exec [[
      CREATE TABLE partitions (id INTEGER PRIMARY KEY, posid INTEGER, note REAL, velocity REAL, length REAL, position REAL, loop REAL);
      CREATE UNIQUE INDEX partitions_id_idx ON partitions(id);
    ]]
  end

  ------------------------------------------------------------  CREATE
  self.create_partition = db:prepare [[
    INSERT INTO partitions VALUES (NULL, :posid, :note, :velocity, :length, :position, :loop);
  ]]

  ------------------------------------------------------------  READ
  self.read_partition_by_id = db:prepare [[
    SELECT * FROM partitions WHERE id = :id;
  ]]

  self.read_partition_by_posid = db:prepare [[
    SELECT * FROM partitions WHERE posid = :posid;
  ]]

  ------------------------------------------------------------  UPDATE
  self.update_partition = db:prepare [[
    UPDATE partitions SET posid = :posid, note = :note, velocity = :velocity, length = :length, position = :position, loop = :loop WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_partition = db:prepare [[
    DELETE FROM partitions WHERE id = :id;
  ]]

  
  --==========================================================  EVENTS

  -- events table
  if is_new then
    db:exec [[
      CREATE TABLE events (id INTEGER PRIMARY KEY, partition_id INTEGER, posid INTEGER, note REAL, velocity REAL, length REAL, position REAL, loop REAL);
      CREATE UNIQUE INDEX events_id_idx ON events(id);
      CREATE INDEX events_partition_id_idx ON events(partition_id);
    ]]
  end

  ------------------------------------------------------------  CREATE
  self.create_event = db:prepare [[
    INSERT INTO events VALUES (NULL, :partition_id, :posid, :note, :velocity, :length, :position, :loop);
  ]]

  ------------------------------------------------------------  READ
  self.read_event_by_id = db:prepare [[
    SELECT * FROM events WHERE id = :id;
  ]]

  self.read_event_by_partition_id_and_posid = db:prepare [[
    SELECT * FROM events WHERE partition_id = :partition_id AND posid = :posid;
  ]]

  self.read_events_by_partition_id = db:prepare [[
    SELECT * FROM events WHERE partition_id = :partition_id;
  ]]

  ------------------------------------------------------------  UPDATE
  self.update_event = db:prepare [[
    UPDATE events SET partition_id = :partition_id, posid = :posid, note = :note, velocity = :velocity, length = :length, position = :position, loop = :loop WHERE id = :id;
  ]]

  ------------------------------------------------------------  DELETE
  self.delete_event = db:prepare [[
    DELETE FROM events WHERE id = :id;
  ]]
end



--==========================================================  PRIVATE

function private:eventFromRow(row)
  return seq.Event {
    db           = self,
    id           = row[1],
    partition_id = row[2],
    posid        = row[3],
    note         = row[4],
    velocity     = row[5],
    length       = row[6],
    position     = row[7],
    loop         = row[8],
  }
end

