--[[------------------------------------------------------

  test binseq.Launchpad
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('binseq.Launchpad')
local withUser = should:testWithUser()

function should.autoLoad()
  local l = binseq.Launchpad
  assertType('table', l)
end

function should.returnButton()
  local l = binseq.Launchpad()
  local b = l:button(1,1)
  assertEqual('binseq.LButton', b.type)
end

function withUser.should.communicateWithLaunchpad(t)
  local l = binseq.Launchpad()
  local btn = l:button(1,1)
  btn:setState 'BlinkGreen'
  function btn:press()
    self:setState('Amber')
  end

  function btn:release()
    self:setState('Off')
    t.continue = true
  end

  t:timeout(function()
    return t.continue
  end)
  assertTrue(t.continue)
end

function should.setDefaultButtonAction(t)
  local l = binseq.Launchpad()
  function l:press(row, col)
    local btn = l:button(row, col)
    btn:setState('Amber')

    t.pressed = {row, col}
  end

  function l:release(row, col)
    local btn = l:button(row, col)
    btn:setState('Off')
    t.released = {row, col}
  end

  l:receiveMidi(144, 1, 127)
  assertNil(t.released)

  assertValueEqual({1,2}, t.pressed)
  l:receiveMidi(128, 19, 0)

  assertValueEqual({2,4}, t.released)
end

test.all()

