--[[------------------------------------------------------

  test seq.LBatchView
  ------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.LBatchView')
local withUser = should:testWithUser()

function should.autoLoad()
  local e = seq.LBatchView
  assertType('table', e)
end

test.all()


