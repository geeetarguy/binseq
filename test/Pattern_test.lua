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

test.all()

