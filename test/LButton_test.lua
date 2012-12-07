--[[------------------------------------------------------

  test binseq.LaunchpadButton
  ------------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.LButton')
local withUser = should:testWithUser()

function should.autoLoad()
  local l = binseq.LButton
  assertType('table', l)
end

test.all()



