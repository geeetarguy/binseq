--[[------------------------------------------------------

  binseq.LButton
  --------------

  One button on the Launchpad.

--]]------------------------------------------------------
local lib = {type = 'binseq.LButton'}
lib.__index         = lib
binseq.LButton = lib
local private       = {}

-- Velocity values for colors (using double buffering).
-- red (bit 1, 2)
-- bit 1, 2 (1, 2  ) : => Red
-- bit 3    (4     ) : copy to other buffer
-- bit 4    (8     ) : clear other buffer (used to blink)
-- bit 5, 6 (16, 32) : => Green
-- bit 7    (64    ) : must be 0   
COLOR_TO_NB = {
  Off        = 0,-- 4,
  LightRed   = 1, -- 5,   -- 1 + 4
  Red        = 3, -- 7,   -- 1 + 2 + 4
  LightAmber = 17, -- 21,  -- 1 + 16 + 4
  Amber      = 51, -- 55,  -- 16 + 32 + 1 + 2 + 4
  LightGreen = 16, -- 20,  -- 16 + 4
  Green      = 48, -- 52,  -- 16 + 32 + 4
  -- Blinking version
  BlinkLightRed   = 9,   -- 1 + 8
  BlinkRed        = 11,   -- 1 + 2 + 8
  BlinkLightAmber = 25,  -- 1 + 16 + 8
  BlinkAmber      = 59,  -- 16 + 32 + 1 + 2 + 8
  BlinkLightGreen = 24,  -- 16 + 8
  BlinkGreen      = 56,  -- 16 + 32 + 8
}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- binseq.LButton(...)
function lib.new(pad, row, col)
  local self = {
    pad = pad,
    row = row,
    col = col,
  }
  self.id = row * 16 + col
  if row > 0 then
    -- grid and left buttons
    self.midi_a = 144
    self.midi_b = (row-1)*16 + col - 1
  else
    -- top row (round buttons)
    self.midi_a = 176
    self.midi_b = 104 + col - 1
  end
  return setmetatable(self, lib)
end

function lib:setState(color)
  if color ~= self.state then
    self.state = color
    self.pad:send(self.midi_a, self.midi_b, COLOR_TO_NB[color])
  end
end

