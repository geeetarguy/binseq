--[[------------------------------------------------------

  test seq.Event
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Event')

function should.autoLoad()
  local e = seq.Event
  assertType('table', e)
end

test.all()
