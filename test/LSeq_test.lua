--[[------------------------------------------------------

  test seq.LSeq
  -------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.LSeq')

function should.autoLoad()
  local e = seq.LSeq
  assertType('table', e)
end

function should.createLSeq()
  local ls = seq.LSeq(seq.Sequencer())
  assertEqual('seq.LSeq', ls.type)
end

test.all()


