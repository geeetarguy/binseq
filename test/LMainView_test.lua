--[[------------------------------------------------------

  test binseq.LMainView
  ------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.LMainView')
local withUser = should:testWithUser()

function should.autoLoad()
  local e = binseq.LMainView
  assertType('table', e)
end

function withUser.should.editEvent(t)
  local s = binseq.Sequencer()
  local ls = binseq.LSeq(s)
  assertPass(function()
    ls:loadView('Main')
  end)

  t:timeout(function()
    local e = s.pattern.events[1]
    --return e and e.position and e.position > 0
    return false
  end)
end

test.all()

