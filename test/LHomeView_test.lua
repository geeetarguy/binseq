--[[------------------------------------------------------

  test seq.LHomeView
  ------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.LHomeView')
local withUser = should:testWithUser()

function should.autoLoad()
  local e = seq.LHomeView
  assertType('table', e)
end

test.all()



