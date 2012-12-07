--[[------------------------------------------------------

  test binseq.LPatternView
  --------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.LPatternView')

function should.autoLoad()
  local e = binseq.LPatternView
  assertType('table', e)
end

test.all()
