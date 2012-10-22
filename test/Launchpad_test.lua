--[[------------------------------------------------------

  test seq.Launchpad
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Launchpad')

function should.autoLoad()
  local e = seq.Launchpad
  assertType('table', e)
end

test.all()

