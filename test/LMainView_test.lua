--[[------------------------------------------------------

  test seq.LMainView
  ------------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.LMainView')
local withUser = should:testWithUser()

function should.autoLoad()
  local e = seq.LMainView
  assertType('table', e)
end

function withUser.should.editEvent(t)
  local s = seq.Sequencer()
  local ls = seq.LSeq(s)
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

