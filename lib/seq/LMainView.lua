--[[------------------------------------------------------

  seq.LMainView
  -------------

  This view shows the following elements:

  ( usual global commands )
  [ Amber = defined events. Click = load event below  ]
  [ "                                                 ]
  [ "                                                 ]
  [ "                                                 ]

  [ "                                                 ]
  [ "                                                 ]
  [ "                                                 ]
  [ "                                                 ]

--]]------------------------------------------------------
local lib = {type = 'seq.LMainView'}
lib.__index         = lib
seq.LMainView       = lib
-- Map row operation to function
local press         = {}
-- Map row operation to function
local release       = {}
local private       = {}

--=============================================== CONSTANTS
local POSITION_ROW = 7
local POSITION_BITS = {
  384, -- 4 whole notes   OOOO
  192, -- 2 whole notes   OO
  96,  -- 1 whole note    O
  48,  -- half note       .
  24,  -- quarter note    x
  12,  -- eighth note     xx
  6,   -- 16th note       xxx
  2,   -- 1 tuplet, 2 tuplet
}

local BIT_STATE = {
  'Off',
  'Green',
  'Amber',
  'Red', -- error
}

--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- seq.LMainView(...)
function lib.new(lseq)
  local self = {
    lseq = lseq,
    pad = lseq.pad,
    seq = lseq.seq,
  }
  return setmetatable(self, lib)
end

-- Display view content
function lib:display()
end

function lib:press(row, col)
  local f = press[row]
  if f then
    f(self, row, col)
  else
    self.lseq:press(row, col)
  end
end

function lib:release(row, col)
  local f = release[row]
  if f then
    f(self, row, col)
  else
    self.lseq:release(row, col)
  end
end

function lib:selectNote(row, col)
  local id = (row-1)*16 + col
  local e = self.seq:getEvent(id)
  if not e then
    print("Loading new event", id)
    e = seq.Event()
    e.id = id
    e.is_new = true
  end
  self:editEvent(e, row, col)
end
press[1] = lib.selectNote
press[2] = lib.selectNote
press[3] = lib.selectNote

function lib:editEvent(e, row, col)
  local row = row or (e.id % 16)
  local col = col or (e.id - 16*row)
  -- turn off highlight current event
  if self.btn then
    -- current on button
    self.btn:setState(self.event.is_new and 'Off' or 'Amber')
  end
  self.event = e
  self.btn = self.pad:button(row, col)
  self.btn:setState('Green')
  -- Load event state in rows 4 to 8
  private.loadPosition(self, e)
end

function lib:setPosition(row, col)
  local e = self.event
  if not e then
    -- Red ?
    return
  end
  local p = e.position
  local r = POSITION_BITS[col]
  local bits = self.position_bits
  local b = bits[col]
  p = p - b * r
  if col == 8 then
    -- tuplet bit
    b = (b + 1) % 3
  elseif b == 0 then
    b = 1
  else
    b = 0
  end
  bits[col] = b
  print('setPosition')
  self.event = self.seq:setEvent(e.id, {
    position = p + b * r,
  })
  self.position_buttons[col]:setState(BIT_STATE[b+1])
end
press[POSITION_ROW] = lib.setPosition

-- position is at row POSITION_ROW
function private:loadPosition(e)
  local position = e and e.position or 0
  local btns = self.position_buttons
  local pad = self.pad
  local bits = {}
  self.position_bits = bits
  if not btns then
    btns = {}
    self.position_buttons = btns
    for i=1,8 do
      btns[i] = pad:button(POSITION_ROW, i)
    end
  end
  
  for i=1,8 do
    local r = POSITION_BITS[i]
    local b = math.floor(position / r)
    position = position - b * r
    bits[i] = b
    btns[i]:setState(BIT_STATE[b+1])
  end
end
