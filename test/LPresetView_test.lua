--[[------------------------------------------------------

  test seq.LPresetView
  --------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.LPresetView')

function should.autoLoad()
  local e = seq.LPresetView
  assertType('table', e)
end

test.all()
