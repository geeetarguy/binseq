--[[------------------------------------------------------

  test binseq.Song
  -------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.Song')
local mock = binseq.Song.mock

local gridToPosid = binseq.Event.gridToPosid

function should.autoLoad()
  local e = binseq.Song
  assertType('table', e)
end

function should.loadSequencers()
  local db = mock().db
  local song = db:getSong(1)
  local s1 = song.sequencers_list[1]
  local s2 = song.sequencers_list[2]
  assertEqual('binseq.Sequencer', s1.type)
  assertEqual('binseq.Sequencer', s2.type)
end

function should.respondToHavePattern()
  local song = mock()
  assertTrue(song.patterns[gridToPosid(1,1,0)])
  assertTrue(song.patterns[gridToPosid(2,2,0)])
  assertFalse(song.patterns[gridToPosid(7,2,0)])
end

test.all()
