--[[------------------------------------------------------

  test seq.Song
  -------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Song')
local helper = {}

local gridToPosid = seq.Event.gridToPosid

function should.autoLoad()
  local e = seq.Song
  assertType('table', e)
end

function should.loadSequencers()
  local db = helper.mockSong().db
  local song = db:getSong(1)
  local s1 = song.sequencers[1]
  local s2 = song.sequencers[2]
  assertEqual('seq.Sequencer', s1.type)
  assertEqual('seq.Sequencer', s2.type)
end

function should.loadAllEventsOngetSequencer()
  local db = helper.mockSong()
  -- row, col, page
  -- this should be pattern 17
  local p = db:getSequencer(3, 1, 0)
  assertEqual(17, p.id)

  -- should contain 48 events
  assertEqual(48, #p.events_list)
end

test.all()
