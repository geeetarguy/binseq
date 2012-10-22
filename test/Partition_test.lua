--[[------------------------------------------------------

  test seq.Partition
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Partition')

function should.autoLoad()
  local e = seq.Partition
  assertType('table', e)
end

test.all()

