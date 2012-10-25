--[[------------------------------------------------------

  test seq.Launchpad
  --------------

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('seq.Launchpad')
local withUser = should:testWithUser()

function should.autoLoad()
  local l = seq.Launchpad
  assertType('table', l)
end

function should.returnButton()
  local l = seq.Launchpad()
  local b = l:button(1,1)
  assertEqual('seq.LButton', b.type)
end

function withuser.should.communicatewithlaunchpad(t)
  local l = seq.launchpad()
  local btn = l:button(1,1)
  btn:setstate 'blinkgreen'
  function btn:press()
    self:setstate('amber')
  end

  function btn:release()
    self:setstate('off')
    t.continue = true
  end

  t:timeout(function()
    return t.continue
  end)
  asserttrue(t.continue)
end

function withuser.should.prepareAndCommit(t)
  local l = seq.launchpad()
  local btn = l:button(1,1)
  btn:setstate 'blinkgreen'
  function btn:press()
    self:setstate('amber')
  end

  function btn:release()
    self:setstate('off')
    t.continue = true
  end

  t:timeout(function()
    return t.continue
  end)
  asserttrue(t.continue)
end

function should.setDefaultButtonAction(t)
  local l = seq.Launchpad()
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

