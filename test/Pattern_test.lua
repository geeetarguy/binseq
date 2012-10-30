--[[------------------------------------------------------

  test seq.Pattern
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Pattern')

function should.autoLoad()
  local e = seq.Pattern
  assertType('table', e)
end

function should.createPattern()
  local s
end

function should.loadEvents()
  local s = seq.Song.mock()
  local db = s.db
  local p = db:getOrCreatePattern(17, s.id)
  p:loadEvents()
  local i = 0
  for _, e in pairs(p.events) do
    i = i + 1
  end
  assertEqual(48, i)
end

test.all()

