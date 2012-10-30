--[[------------------------------------------------------

  test seq.Song
  -------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Song')
local mock = seq.Song.mock

local gridToPosid = seq.Event.gridToPosid

function should.autoLoad()
  local e = seq.Song
  assertType('table', e)
end

function should.loadSequencers()
  local db = mock().db
  local song = db:getSong(1)
  local s1 = song.sequencers_list[1]
  local s2 = song.sequencers_list[2]
  assertEqual('seq.Sequencer', s1.type)
  assertEqual('seq.Sequencer', s2.type)
end

function should.respondToHavePattern()
  local song = mock()
  assertTrue(song.patterns[gridToPosid(1,1,0)])
  assertTrue(song.patterns[gridToPosid(2,2,0)])
  assertFalse(song.patterns[gridToPosid(7,2,0)])
end

test.all()