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

function helper.mockSong()
  local db = seq.PresetDb(':memory')
  local song = db:createSong(1, 'hello')
  for row = 1,8 do
    for col = 1,8 do
      song:createPattern(gridToPosid(row, col, 0))
    end
  end

  for _, pat_id in ipairs {12, 15, 17, 1} do
    -- Only fill 6 rows = 48 events
    local pat = song:getPattern(pat_id)
    for row = 1,6 do
      for col = 1,8 do
        local posid = gridToPosid(row, col, 0)
        local e = pat:createEvent(posid)
      end
    end
  end

  -- create 2 sequencers
  for _, col in ipairs {1, 3} do
    local seq = song:createSequencer(gridToPosid(1, col, 0))
    -- activate some patterns
    seq:enablePattern(gridToPosid(1, col, 0))
    seq:enablePattern(gridToPosid(2, col+1, 0))
  end
  return song
end

test.all()
