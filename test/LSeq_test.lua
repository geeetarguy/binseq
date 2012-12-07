--[[------------------------------------------------------

  test binseq.LSeq
  -------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.LSeq')

function should.autoLoad()
  local e = binseq.LSeq
  assertType('table', e)
end

function should.createLSeq()
  local ls = binseq.LSeq(':memory:')
  assertEqual('binseq.LSeq', ls.type)
end

test.all()


