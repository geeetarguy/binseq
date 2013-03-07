--[[------------------------------------------------------

  test binseq.Preset
  -------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.Preset')
local mock = binseq.Song.mock

function should.autoLoad()
  assertType('table', binseq.Preset)
end

function should.createEmpty()
  local p = binseq.Preset()
  assertValueEqual({}, p.patterns)
end

function should.createWithSong()
  local song = mock()
  local p = binseq.Preset { song = song }
  assertValueEqual({
    [1]  = 2,
    [3]  = 4,
    [10] = 11,
    [12] = 13,
  }, p.patterns)
end

function should.dump()
  local song = mock()
  local p = binseq.Preset { song = song }
  assertValueEqual({
    patterns = {
      ['1']  = 2,
      ['3']  = 4,
      ['10'] = 11,
      ['12'] = 13,
    },
  }, p:dump())
end

function should.createWithData()
  local song = mock()
  local p = binseq.Preset {
    data = {
      patterns = {
        ['11'] = 20,
        ['2']  = 24,
        ['14'] = 51,
        ['72'] = 413,
      },
    }
  }
  assertValueEqual({
    [11]  = 20,
    [2]  = 24,
    [14] = 51,
    [72] = 413,
  }, p.patterns)
end

local function activePatterns(song)
  local p = {}
  for posid, pat in pairs(song.patterns) do
    if pat.seq then
      lk.insertSorted(p, pat.posid)
    end
  end
  return p
end

function should.activate()
  local song = mock()
  local p = binseq.Preset {
    data = {
      patterns = {
        ['11'] = 12,
        ['2']  = 3,
        -- wrong pattern id
        ['14'] = 21,
        ['42'] = 43,
      },
    }
  }

  assertValueEqual(
    {1, 3, 10, 12},
    activePatterns(song)
  )

  song:activatePreset(p)

  assertValueEqual(
    {2, 11, 42},
    activePatterns(song)
  )
end
test.all()

