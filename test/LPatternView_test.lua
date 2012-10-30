--[[------------------------------------------------------

  test seq.LPatternView
  --------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.LPatternView')

function should.autoLoad()
  local e = seq.LPatternView
  assertType('table', e)
end

test.all()
