--[[------------------------------------------------------

  test binseq.Database
  -----------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.Database')
local helper = {}

local gridToPosid = binseq.Event.gridToPosid

function should.autoLoad()
  local e = binseq.Database
  assertType('table', e)
end

function should.openInMemory()
  assertPass(function()
    local db = binseq.Database(':memory:')
  end)
end

--===================================== Song
function should.getOrCreateSong()
  local db = binseq.Database(':memory:')
  -- row, col, page
  local p = db:getOrCreateSong(5, 'foobar')
  assertEqual('binseq.Song', p.type)
  assertEqual(1, p.id)
  assertEqual(5, p.posid)
  assertEqual('foobar', p.name)
  p = db:getOrCreateSong(6)
  assertEqual(2, p.id)
end

function should.getSong()
  local db = binseq.Database(':memory:')
  local p1 = db:getOrCreateSong(5, 'fool')
  local p2 = db:getSong(5)
  assertEqual(p1.id, p2.id)
  assertEqual('fool', p2.name)
  assertEqual('binseq.Song', p2.type)
  assertEqual(p1.posid, p2.posid)
end

function should.getSongs()
  local db = binseq.Database(':memory:')
  local s1 = db:getOrCreateSong(35, 'bar')
  local s2 = db:getOrCreateSong(5, 'foo')
  local res = {}
  for s in db:getSongs() do
    table.insert(res, {s.posid, s.name})
  end

  assertValueEqual({
    {5, 'foo'},
    {35,'bar'},
  }, res)
end

function should.updateSong()
  local db = binseq.Database(':memory:')
  local p = db:getOrCreateSong(5, 'bar')
  assertEqual('bar', p.name)
  p.name = 'foo'
  p:save()
  p = db:getSong(5)
  assertEqual('foo', p.name)
end

function should.deleteSong()
  local db = binseq.Database(':memory:')
  local p = db:getOrCreateSong(5)
  p:delete()
  p = db:getSong(5)
  assertNil(p)
end

function should.deleteAllPatternsAndEvents()
  local db   = binseq.Database(':memory:')
  local song = db:getOrCreateSong(5)
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
  local db = binseq.Database(':memory:')
  -- posid, song_id
  local p = db:getOrCreateSequencer(5, 1)
  assertEqual('binseq.Sequencer', p.type)
  assertEqual(1, p.id)
  assertEqual(5, p.posid)
  p = db:getOrCreateSequencer(3, 2)
  assertEqual(2, p.id)
end

function should.getSequencer()
  local db = binseq.Database(':memory:')
  -- posid, song_id
  local p1 = db:getOrCreateSequencer(5, 1)
  local p2 = db:getOrCreateSequencer(5, 1)
  assertEqual(p1.id, p2.id)
  assertEqual('binseq.Sequencer', p2.type)
  assertEqual(p1.posid, p2.posid)
end

function should.getSequencers()
  local db = binseq.Database(':memory:')
  -- posid, song_id
  local s1 = db:getOrCreateSequencer(3, 1)
  local s2 = db:getOrCreateSequencer(5, 1)
  local list = {}
  for s in db:getSequencers(1) do
    table.insert(list, s.type)
    table.insert(list, s.id)
  end
  assertValueEqual({
    'binseq.Sequencer', s1.id,
    'binseq.Sequencer', s2.id,
  }, list)
end

function should.saveSequencerId()
  local db = binseq.Database(':memory:')
  -- posid, song_id
  local s = db:getOrCreateSequencer(5, 1)
  local p = db:getOrCreatePattern(3, s.id)
  p.sequencer_id = s.id
  p:save()

  p = db:getPattern(3, s.id)
  assertEqual(s.id, p.sequencer_id)
end

function should.updateSequencer()
  local db = binseq.Database(':memory:')
  -- posid, song_id
  local s = db:getOrCreateSequencer(5, 3)
  assertEqual(1, s.channel)
  s.channel = 4
  s:save()
  s = db:getSequencer(5, 3)
  assertEqual(4, s.channel)
end

function should.deleteSequencer()
  local db = binseq.Database(':memory:')
  -- posid, song_id
  local p = db:getOrCreateSequencer(5, 3)
  p:delete()
  p = db:getSequencer(5)
  assertNil(p)
end

--===================================== Patterns
function should.getOrCreatePattern()
  local db = binseq.Database(':memory:')
  -- posid, song_id
  local p = db:getOrCreatePattern(5, 1)
  assertEqual('binseq.Pattern', p.type)
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
  local db = binseq.Database(':memory:')
  -- row, col, page
  local p1 = db:getOrCreatePattern(5, 1)
  local p2 = db:getPattern(5, 1)
  assertEqual(p1.id, p2.id)
  assertNil(db:getPattern(5, 2))
  assertEqual('binseq.Pattern', p2.type)
  assertEqual(p1.posid, p2.posid)

  local p3 = db:getOrCreatePattern(5, 2)
  assertEqual(p3.id, db:getPattern(5, 2).id)
  assertNotEqual(p1.id, p3.id)
end

function should.loadAllEventsOngetPattern()
  local song = binseq.Song.mock()
  -- this should be pattern 17
  local p = song:getOrCreatePattern(gridToPosid(3, 1, 0))
  assertEqual(17, p.posid)

  -- should contain 48 events
  local i = 0
  for k, v in pairs(p.events) do
    i = i + 1
  end
  assertEqual(48, i)
  assertEqual('binseq.Event', p.events[13].type)
end

function should.updatePattern()
  local db = binseq.Database(':memory:')
  -- row, col, page
  local p = db:getOrCreatePattern(5, 1)
  assertEqual(1, p.song_id)
  p.song_id = 48
  p:save()
  p = db:getPattern(5, 48)
  assertEqual(48, p.song_id)
end

function should.deletePattern()
  local db = binseq.Database(':memory:')
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
  local db = binseq.Database(':memory:')
  -- row, col, page
  local e = db:getOrCreateEvent(5, 17)
  assertEqual('binseq.Event', e.type)
  assertEqual(1, e.id)
  assertEqual(17, e.pattern_id)
  assertEqual(5, e.posid)
  e = db:getOrCreateEvent(6, 17)
  assertEqual(2, e.id)
  assertEqual(6, e.posid)
end

function should.getEvent()
  local db = binseq.Database(':memory:')
  -- row, col, page, pattern_id
  local p1 = db:getOrCreateEvent(5, 17)
  local p2 = db:getEvent(5, 17)
  assertEqual(p1.id, p2.id)
  assertEqual('binseq.Event', p2.type)
  assertEqual(p1.posid, p2.posid)
end

function should.updateEvent()
  local db = binseq.Database(':memory:')
  -- row, col, page
  local p = db:getOrCreateEvent(5, 17)
  assertEqual(24, p.loop)
  p.loop = 48
  p:save()
  p = db:getEvent(5, 17)
  assertEqual(48, p.loop)
end

function should.storeMute()
  local db = binseq.Database(':memory:')
  -- row, col, page, pattern_id
  local p1 = db:getOrCreateEvent(5, 17)
  -- auto save
  p1:set {mute = 0}

  local p2 = db:getEvent(5, 17)
  assertEqual(0, p2.mute)
end

function should.storeCtrl()
  local db = binseq.Database(':memory:')
  -- row, col, page, pattern_id
  local p1 = db:getOrCreateEvent(5, 17)
  assertNil(p1.ctrl)
  -- auto save
  p1:set {ctrl = 20}

  local p2 = db:getEvent(5, 17)
  assertEqual(20, p2.ctrl)
end

function should.savePatternTuning()
  local db = binseq.Database(':memory:')
  local song = db:getOrCreateSong(5)
  local pat  = song:getOrCreatePattern(6)
  pat.note = 23
  pat:save()

  local p2 = db:getPattern(6, song.id)
  assertEqual(23, p2.note)
end

function should.deleteEvent()
  local db = binseq.Database(':memory:')
  -- row, col, page
  local e = db:getOrCreateEvent(5, 17)
  e:delete()
  e = db:getEvent(5, 17)
  assertNil(e)
end

function should.saveAndRestoreGlobal()
  local db = binseq.Database ':memory:'
  assertValueEqual({}, db:getGlobals())
  db:setGlobals {
    foo = 'bar',
    baz = 'bom',
    song_id = 4,
  }

  assertValueEqual({
    foo = 'bar',
    baz = 'bom',
    song_id = 4,
  }, db:getGlobals())
end

test.all()
