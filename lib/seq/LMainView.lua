--[[------------------------------------------------------

  seq.LMainView
  -------------

  This view shows the following elements:

  ( usual global commands )
  [ Amber = defined events. Click = load event below  ]
  [ "                                                 ]
  [ "                                                 ]
  [ velocity (0 = remove event)                       ]

  [ note (midi note value)                            ]
  [ length                                            ]
  [ position                                          ]
  [ loop length (per event)                           ] (use this as global)

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
local PARAMS = {'note', 'velocity', 'loop', 'length', 'position'}
local ROW_INDEX = {}
for i, k in ipairs(PARAMS) do
  ROW_INDEX[k] = i + 3
end

local BITS = {
  note     = {
    4*12, -- 4 octaves
    2*12, -- 2 octaves
    12,   -- octave
    8,    -- 6th minor (Perfect fifth + half tone)
    4,    -- major third
    2,    -- tone
    1,    -- half tone
    'mute',  -- mute (set as event.mute, not stored in note value)
  },
  velocity = {
    64,
    32,
    16,
    8,
    4,
    2,
    1,
    '',  -- ignore
  },
  position = {
    384, -- 4 whole notes   OOOO
    192, -- 2 whole notes   OO
    96,  -- 1 whole note    O
    48,  -- half note       .
    24,  -- quarter note    x
    12,  -- eighth note     xx
    6,   -- 16th note       xxx
    2,   -- 1 tuplet, 2 tuplet
  },
}

BITS.loop   = BITS.position
BITS.length = BITS.position

local BIT_STATE = {
  'Off',
  'Green',
  'Amber',
  'Red', -- mute
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
    -- direct access to buttons (ex: btns.position[col])
    btns = {},
    -- direct access to bit values (ex: bits.position[col])
    bits = {},
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
  self.pad:prepare()
    self.btn:setState('Green')
    -- Load event state in rows 4 to 8
    -- position is at row ROW_INDEX.position
    private.loadParam(self, 'position', e)
    for _, key in ipairs(PARAMS) do
      private.loadParam(self, key, e)
    end
  self.pad:commit()
end

for _, key in ipairs(PARAMS) do
  -- On button press for row ROW_INDEX[key], call setParam
  press[ROW_INDEX[key]] = function(self, row, col)
    private.setParam(self, key, row, col)
  end
end

function private:setParam(key, row, col)
  local e = self.event
  if not e then
    -- Red ?
    return
  end
  local p = e[key]
  local r = BITS[key][col]
  local bits = self.bits[key]
  local b = bits[col]
  if type(r) == 'string' then
    -- special operation
    if r == 'mute' then
      b = e.mute and 0 or 3
      bits[col] = b
      self.event = self.seq:setEvent(e.id, {
        mute = b == 3
      })
    else
      -- ignore
      return
    end
  else
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
    self.event = self.seq:setEvent(e.id, {
      [key] = p + b * r,
    })
  end
  self.btns[key][col]:setState(BIT_STATE[b+1])
end

function private:loadParam(key, e)
  local position = e and e[key] or 0
  local btns = self.btns[key]
  local pad = self.pad
  local bits = {}
  self.bits[key] = bits
  if not btns then
    local row = ROW_INDEX[key]
    btns = {}
    self.btns[key] = btns
    for i=1,8 do
      btns[i] = pad:button(row, i)
    end
  end
  
  local bit_values = BITS[key]
  for i=1,8 do
    local r = bit_values[i]
    local b
    if type(r) == 'string' then
      if r == 'mute' then
        b = e.mute and 3 or 0
      else
        -- ignore
        b = 0
      end
    else
      b = math.floor(position / r)
      if key == 'note' and b > 1 then
        b = 1
      end
      position = position - b * r
    end
    bits[i] = b
    btns[i]:setState(BIT_STATE[b+1])
  end
end
