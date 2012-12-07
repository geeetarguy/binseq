--[[------------------------------------------------------

  test binseq.LHomeView
  ------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.LHomeView')
local withUser = should:testWithUser()

function should.autoLoad()
  local e = binseq.LHomeView
  assertType('table', e)
end

test.all()



