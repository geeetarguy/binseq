--[[------------------------------------------------------

  test seq.PresetDb
  -----------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.PresetDb')
local helper = {}

local gridToPosid = seq.Event.gridToPosid

function should.autoLoad()
  local e = seq.PresetDb
  assertType('table', e)
end

function should.openInMemory()
  assertPass(function()
    local db = seq.PresetDb(':memory')
  end)
end

--===================================== Song
function should.createSong()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p = db:createSong(5, 'foobar')
  assertEqual('seq.Song', p.type)
  assertEqual(1, p.id)
  assertEqual(5, p.posid)
  assertEqual('foobar', p.name)
  p = db:createSong(6)
  assertEqual(2, p.id)
end

function should.getSong()
  local db = seq.PresetDb(':memory')
  local p1 = db:createSong(5, 'fool')
  local p2 = db:getSong(5)
  assertEqual(p1.id, p2.id)
  assertEqual('fool', p2.name)
  assertEqual('seq.Song', p2.type)
  assertEqual(p1.posid, p2.posid)
end

function should.updateSong()
  local db = seq.PresetDb(':memory')
  local p = db:createSong(5, 'bar')
  assertEqual('bar', p.name)
  p.name = 'foo'
  p:save()
  p = db:getSong(5)
  assertEqual('foo', p.name)
end

function should.deleteSong()
  local db = seq.PresetDb(':memory')
  local p = db:createSong(5)
  p:delete()
  p = db:getSong(5)
  assertNil(p)
end

function should.deleteAllPatternsAndEvents()
  local db   = seq.PresetDb(':memory')
  local song = db:createSong(5)
  local pat  = song:getOrCreatePattern(6)
  local pat2 = song:getOrCreatePattern(7)
  local e    = pat:getOrCreateEvent(3)
  assertTrue(db:getSong(5))
  assertTrue(db:getPattern(6, song.id))
  assertTrue(db:getPattern(7, song.id))
  assertTrue(db:getEvent(3, pat.id))

  song:delete()
  assertTrue(song.deleted)
  assertNil(db:getSong(5))
  assertNil(db:getPattern(6, song.id))
  assertNil(db:getPattern(7, song.id))
  assertNil(db:getEvent(3, pat.id))
end

--===================================== Sequencers
function should.createSequencer()
  local db = seq.PresetDb(':memory')
  -- posid, song_id
  local p = db:getOrCreateSequencer(5, 1)
  assertEqual('seq.Sequencer', p.type)
  assertEqual(1, p.id)
  assertEqual(5, p.posid)
  p = db:getOrCreateSequencer(3, 2)
  assertEqual(2, p.id)
end

function should.getSequencer()
  local db = seq.PresetDb(':memory')
  -- posid, song_id
  local p1 = db:getOrCreateSequencer(5, 1)
  local p2 = db:getOrCreateSequencer(5, 1)
  assertEqual(p1.id, p2.id)
  assertEqual('seq.Sequencer', p2.type)
  assertEqual(p1.posid, p2.posid)
end

function should.updateSequencer()
  local db = seq.PresetDb(':memory')
  -- posid, song_id
  local s = db:getOrCreateSequencer(5, 3)
  assertEqual(0, s.loop)
  s.loop = 48
  s:save()
  s = db:getSequencer(5, 3)
  assertEqual(48, s.loop)
end

function should.deleteSequencer()
  local db = seq.PresetDb(':memory')
  -- posid, song_id
  local p = db:getOrCreateSequencer(5, 3)
  assertEqual(0, p.loop)
  p:delete()
  p = db:getSequencer(5)
  assertNil(p)
end

--===================================== Patterns
function should.getOrCreatePattern()
  local db = seq.PresetDb(':memory')
  -- posid, song_id
  local p = db:getOrCreatePattern(5, 1)
  assertEqual('seq.Pattern', p.type)
  assertEqual(1, p.id)
  assertEqual(5, p.posid)
  p = db:getOrCreatePattern(3, 1)
  assertEqual(2, p.id)
  p = db:getOrCreatePattern(5, 1)
  -- Trying to create on existing position returns existing object.
  assertEqual(1, p.id)
  assertNotEqual(p.id, db:getOrCreatePattern(5, 2).id)
end

function should.getPattern()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p1 = db:getOrCreatePattern(5, 1)
  local p2 = db:getPattern(5, 1)
  assertEqual(p1.id, p2.id)
  assertNil(db:getPattern(5, 2))
  assertEqual('seq.Pattern', p2.type)
  assertEqual(p1.posid, p2.posid)

  local p3 = db:getOrCreatePattern(5, 2)
  assertEqual(p3.id, db:getPattern(5, 2).id)
  assertNotEqual(p1.id, p3.id)
end

function should.loadAllEventsOngetPattern()
  local song = helper.mockSong()
  -- this should be pattern 17
  local p = song:getOrCreatePattern(gridToPosid(3, 1, 0))
  assertEqual(17, p.posid)

  -- should contain 48 events
  local i = 0
  for k, v in pairs(p.events) do
    i = i + 1
  end
  assertEqual(48, i)
  assertEqual('seq.Event', p.events[13].type)
end

function should.updatePattern()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p = db:getOrCreatePattern(5, 1)
  assertEqual(1, p.song_id)
  p.song_id = 48
  p:save()
  p = db:getPattern(5, 48)
  assertEqual(48, p.song_id)
end

function should.deletePattern()
  local db = seq.PresetDb(':memory')
  -- posid, song_id
  local p = db:getOrCreatePattern(5, 1)
  local e = p:getOrCreateEvent(3)
  p:delete()
  assertNil(db:getPattern(5, 1))
  assertTrue(p.deleted)
  -- should delete all linked events
  assertNil(db:getEvent(5, p.id))
  assertTrue(e.deleted)
end

--===================================== Event
function should.getOrCreateEvent()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local e = db:getOrCreateEvent(5, 17)
  assertEqual('seq.Event', e.type)
  assertEqual(1, e.id)
  assertEqual(17, e.pattern_id)
  assertEqual(5, e.posid)
  e = db:getOrCreateEvent(6, 17)
  assertEqual(2, e.id)
  assertEqual(6, e.posid)
end

function should.getEvent()
  local db = seq.PresetDb(':memory')
  -- row, col, page, pattern_id
  local p1 = db:getOrCreateEvent(5, 17)
  local p2 = db:getEvent(5, 17)
  assertEqual(p1.id, p2.id)
  assertEqual('seq.Event', p2.type)
  assertEqual(p1.posid, p2.posid)
end

function should.updateEvent()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local p = db:getOrCreateEvent(5, 17)
  assertEqual(24, p.loop)
  p.loop = 48
  p:save()
  p = db:getEvent(5, 17)
  assertEqual(48, p.loop)
end

function should.storeMute()
  local db = seq.PresetDb(':memory')
  -- row, col, page, pattern_id
  local p1 = db:getOrCreateEvent(5, 17)
  -- auto save
  p1:set {mute = 0}

  local p2 = db:getEvent(5, 17)
  assertEqual(0, p2.mute)
end

function should.deleteEvent()
  local db = seq.PresetDb(':memory')
  -- row, col, page
  local e = db:getOrCreateEvent(5, 17)
  e:delete()
  e = db:getEvent(5, 17)
  assertNil(e)
end

--]=]

function helper.mockSong()
  local db = seq.PresetDb(':memory')
  local song = db:createSong(1, 'hello')
  for row = 1,8 do
    for col = 1,8 do
      song:getOrCreatePattern(seq.Event.gridToPosid(row, col, 0))
    end
  end

  for _, pat_id in ipairs {12, 15, 17, 1} do
    -- Only fill 6 rows = 48 events
    local pat = song:getOrCreatePattern(pat_id)
    for row = 1,6 do
      for col = 1,8 do
        local posid = gridToPosid(row, col, 0)
        local e = pat:getOrCreateEvent(posid)
      end
    end
  end
  return song
end

test.all()
