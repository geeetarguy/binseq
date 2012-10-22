--[[------------------------------------------------------

  test seq.Sequencer
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Sequencer')

function should.autoLoad()
  local e = seq.Sequencer
  assertType('table', e)
end

test.all()
