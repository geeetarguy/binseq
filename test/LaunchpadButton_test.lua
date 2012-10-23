--[[------------------------------------------------------

  test seq.LaunchpadButton
  ------------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.LaunchpadButton')
local withUser = should:testWithUser()

function should.autoLoad()
  local l = seq.LaunchpadButton
  assertType('table', l)
end

test.all()



