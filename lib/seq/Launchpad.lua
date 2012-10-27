--[[------------------------------------------------------

  seq.Launchpad
  -------------

  The Launchpad is a view for the Sequencer and is
  connected to novation Launchpad via midi.

--]]------------------------------------------------------
local lib = {type = 'seq.Launchpad'}
lib.__index      = lib
seq.Launchpad    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.Launchpad(...)
function lib.new()
  local self = {
    lin = midi.In('Launchpad'),
    out = midi.Out('Launchpad'),
    buttons = {},
    copy_bit = 4,
  }
  self.finalizer = lk.Finalizer(function()
    self:clear()
  end)

  function self.lin.rawReceive(lin, a, b, c)
    self:receiveMidi(a, b, c)
  end
  setmetatable(self, lib)
  -- clear Launchpad
  self:clear()
  self.out:send(176, 0, 48)
  -- -- set blink mode
  -- self:blink('auto')
  -- make sure display/update buffers are in 'commit' mode
  -- self:commit()
  return self
end

function lib:clear()
  self.out:send(176, 0, 0)
  local buttons = self.buttons
  for row=0,8 do
    for col=1,9 do
      local id = row * 16 + col
      local btn = buttons[id]
      if btn then
        btn.state = 'Off'
      end
    end
  end
end

function lib:blink(mode)
  if mode == 'auto' then
    self.out:send(176, 0, 40)
  else
    self.blink_on = not self.blink_on
    self.out:send(176, 0, self.blink_on and 32 or 33)
  end
end

function lib:button(row, col)
  local btn_id = row * 16 + col
  local b = self.buttons[btn_id]
  if not b then
    b = seq.LButton(self, row, col)
    self.buttons[btn_id] = b
  end
  return b
end

function lib:receiveMidi(a, b, c)
  local key = c == 127 and 'press' or 'release'
  local btn_id

  if a == 176 then
    -- top button event (1 indexed)
    btn_id = b - 103
  else
    -- grid button event (1 indexed)
    btn_id = b + 17
  end
  local row = math.floor(btn_id / 16)
  local col = btn_id - row * 16

  local view = self.view
  if view then
    -- View acts as delegate for events.
    local f = view[key]
    if f then
      f(view, row, col)
    end
  else
    local btn = self.buttons[btn_id]
    local f = btn and btn[key]
    if f then
      f(btn)
    else
      -- Default action
      f = self[key]
      if f then
        f(self, row, col)
      end
    end
  end
end

-- A view acts as a delegate for all received midi operations. It should
-- respond to 'display()', 'press(row, col)' and 'release(row, col)'.
function lib:loadView(view, ...)
  self.view = view
  view:display(...)
end

-- bit 1 (1 ) : DISPLAY buffer
-- bit 2 (2 ) : must be 0
-- bit 3 (4 ) : UPDATE  buffer
-- bit 4 (8 ) : flash
-- bit 5 (16) : copy new DISPLAY to new UPDATE buffer
-- bit 6 (32) : must be 1
-- bit 7 (64) : must be 0
-- start double buffering
function lib:prepare()
  -- Do not add copy bit on prepare/commit
  self.copy_bit = 0
  -- DISPLAY in 1, UPDATE in 0
  -- 1 + 0 + 0 + 0 + 16 + 32 = 49
  self.out:send(176, 0, 49)
end

-- commit changes
function lib:commit()
  -- Add copy bit after commit
  self.copy_bit = 4
  -- DISPLAY in 0, UPDATE in 0
  -- 0 + 0 + 0 + 0 + 16 + 32 = 48
  self.out:send(176, 0, 48)
end  

function lib:send(a, b, c)
  self.out:send(a, b, c + self.copy_bit)
end
