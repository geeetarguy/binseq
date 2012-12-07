--[[------------------------------------------------------

  test binseq.LBatchView
  ------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.LBatchView')
local withUser = should:testWithUser()

function should.autoLoad()
  local e = binseq.LBatchView
  assertType('table', e)
end

test.all()


