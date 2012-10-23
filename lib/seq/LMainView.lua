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
local PARAMS = {'note', 'velocity', 'length', 'position', 'loop'}
local ROW_INDEX = {}
for i, k in ipairs(PARAMS) do
  ROW_INDEX[k] = i + 3
end

local BITS = {
  note     = {
    'mute',  -- mute (set as event.mute, not stored in note value)
    4*12, -- 4 octaves
    2*12, -- 2 octaves
    12,   -- octave
    8,    -- 6th minor (Perfect fifth + half tone)
    4,    -- major third
    2,    -- tone
    1,    -- half tone
  },
  velocity = {
    '',  -- ignore
    64,
    32,
    16,
    8,
    4,
    2,
    1,
  },
  length = {
    192, -- 2 whole notes   OO
    96,  -- 1 whole note    O
    48,  -- half note       o
    24,  -- quarter note    .
    12,  -- eighth note     x
    6,   -- 16th note       xx
    3,   -- 32th note       xxx
    1,   -- 1 tuplet, 2 tuplet
  },
  position = {
    192, -- 2 whole notes   OO
    96,  -- 1 whole note    O
    48,  -- half note       o
    24,  -- quarter note    .
    12,  -- eighth note     x
    6,   -- 16th note       xx
    3,   -- 32th note       xxx
    1,   -- 1 tuplet, 2 tuplet
  },
  loop = {
    192, -- 2 whole notes   OO
    96,  -- 1 whole note    O
    48,  -- half note       o
    24,  -- quarter note    .
    12,  -- eighth note     x
    6,   -- 16th note       xx
    3,   -- 32th note       xxx
    1,   -- 1 tuplet, 2 tuplet
    'global',
  },
}

local BIT_STATE = {
  'Off',
  'Green',
  'Amber',
  'LightRed', -- mute
}

local GLOBAL_LOOP_BIT_STATE = {
  'Off',
  'Amber',
  'LightGreen',
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
      if key == 'loop' then
        local seq = self.seq
        if seq.global_loop then
          -- Dispaly global loop setting instead
          private.loadParam(self, key, nil, seq.global_loop, GLOBAL_LOOP_BIT_STATE)
        else
          private.loadParam(self, key, e)
        end
      else
        private.loadParam(self, key, e)
      end
    end
  self.pad:commit()
end

for _, key in ipairs(PARAMS) do
  press[ROW_INDEX[key]] = function(self, row, col)
    private.setParam(self, key, row, col)
  end
end

function private:setParam(key, row, col)
  local states = BIT_STATE
  local seq = self.seq
  if key == 'loop' and seq.global_loop then
    states = GLOBAL_LOOP_BIT_STATE
  end
  local e = self.event
  if not e then
    -- Red ?
    return
  end
  local p
  if key == 'loop' and seq.global_loop then
    p = seq.global_loop
  else
    p = e[key]
  end
  local r = BITS[key][col]
  local bits = self.bits[key]
  local b = bits[col]
  if type(r) == 'string' then
    -- special operation
    if r == 'mute' then
      b = e.mute and 0 or 3
      bits[col] = b
      self.event = seq:setEvent(e.id, {
        mute = b == 3
      })
    elseif r == 'global' and key == 'loop' then
      -- set current value for 'key' as global parameter
      if seq.global_loop then
        -- turn off
        seq.global_loop_value = seq.global_loop
        seq:setGlobalLoop(nil)
        private.loadParam(self, key, e)
        b = 0
      else
        -- turn on
        seq:setGlobalLoop(seq.global_loop_value or 96)
        private.loadParam(self, key, nil, seq.global_loop, GLOBAL_LOOP_BIT_STATE)
        b = 2
      end
    else
      -- ignore
      return
    end
  elseif r then
    p = p - b * r
    if col == 8 and (key == 'loop' or key == 'length' or key == 'position') then
      -- tuplet bit
      b = (b + 1) % 3
    elseif b == 0 then
      b = 1
    else
      b = 0
    end
    bits[col] = b
    if key == 'loop' and seq.global_loop then
      -- update global loop
      seq:setGlobalLoop(p + b * r)
    else
      self.event = seq:setEvent(e.id, {
        [key] = p + b * r,
      })
    end
  else
    b = 0
  end
  self.btns[key][col]:setState(states[b+1])
end

function private:loadParam(key, e, value, states)
  local states = states or BIT_STATE
  local value = value or (e and e[key]) or 0
  local btns = self.btns[key]
  local pad = self.pad
  local bits = {}
  self.bits[key] = bits
  if not btns then
    local row = ROW_INDEX[key]
    btns = {}
    self.btns[key] = btns
    for i=1,9 do
      btns[i] = pad:button(row, i)
    end
  end
  
  local bit_values = BITS[key]
  for i=1,9 do
    local r = bit_values[i]
    local b
    if type(r) == 'string' then
      if r == 'mute' then
        b = e.mute and 3 or 0
      elseif r == 'global' and key == 'loop' then
        b = self.seq.global_loop and 1 or 0
      else
        -- ignore
        b = 0
      end
    elseif r then
      b = math.floor(value / r)
      if key == 'note' and b > 1 then
        b = 1
      end
      value = value - b * r
    else
      b = 0
    end
    bits[i] = b
    btns[i]:setState(states[b+1])
  end
end
