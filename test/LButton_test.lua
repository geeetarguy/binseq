--[[------------------------------------------------------

  test seq.LaunchpadButton
  ------------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.LButton')
local withUser = should:testWithUser()

function should.autoLoad()
  local l = seq.LButton
  assertType('table', l)
end

test.all()



