--[[------------------------------------------------------

  seq.LMainView
  -------------

  This view shows the following elements:

  ( usual global commands )
  [ LightAmber = defined events. Click = load event below  ]
  [ "                                                 ]
  [ "                                                 ]
  [ note (midi note value)                            ]

  [ velocity (0 = remove event)                       ]
  [ length                                            ]
  [ position                                          ]
  [ loop length (per event)                           ] (use this as global)

--]]------------------------------------------------------
local lib = {type = 'seq.LMainView', name = 'Main'}
lib.__index         = lib
seq.LMainView       = lib
-- Last column operation to function
local col_button    = {}
-- Map row operation to function
local grid_button   = {}
-- Map top buttons
local top_button    = {}
-- Map row operation to function
local release       = {}
local private       = {}

--=============================================== CONSTANTS
local PARAMS = {'', '', '', 'note', 'velocity', 'position', 'length', 'loop'}
local ROW_INDEX = {}
for i, k in ipairs(PARAMS) do
  if k ~= '' then
    ROW_INDEX[k] = i
  end
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
    -- Adding 1000 = triple mode: 0, 1, 2
    1384,  -- 4 whole notes   OOO, OOO OOO
    1096,  -- 1 whole note    O, OO
    48,    -- half note       o
    24,    -- quarter note    .
    12,    -- eighth note     x
    6,     -- 16th note       xx
    3,     -- 32th note       xxx
    1001,   -- 1 tuplet, 2 tuplet
  },
  position = {
    -- Adding 1000 = triple mode: 0, 1, 2
    1384,  -- 4 whole notes   OOO, OOO OOO
    1096,  -- 1 whole note    O, OO
    48,  -- half note       o
    24,  -- quarter note    .
    12,  -- eighth note     x
    6,   -- 16th note       xx
    3,   -- 32th note       xxx
    1001,   -- 1 tuplet, 2 tuplet
  },
  loop = {
    -- Adding 1000 = triple mode: 0, 1, 2
    1384,  -- 4 whole notes   OOOO, OOOOOOOO
    1096,  -- 1 whole note    O, OO
    48,  -- half note       o
    24,  -- quarter note    .
    12,  -- eighth note     x
    6,   -- 16th note       xx
    3,   -- 32th note       xxx
    1001,   -- 1 tuplet, 2 tuplet
  },
}

local BIT_STATE = {
  'Off',
  'Amber',
  'Green',
  -- mute states
  'Off',
  'LightRed',
  'LightRed',
  'Red', -- mute button
}


local GLOBAL_LOOP_BIT_STATE = {
  'Off',
  'Amber',
  'LightGreen',
}

local EVENT_LIST = {
  'Off',
  'LightGreen',
  'LightAmber', -- loaded
  '', -- Never occurs (cannot have NoteOn of inexistant event)
  'Green', -- NoteOn
  'Amber', -- NoteOn on loaded
  'LightRed', -- muted
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

-- Display view content (called on load)
function lib:display()
  local pad = self.pad
  local seq = self.seq
  local events = seq.partition.events
  local event = self.event
  -- Clear
  pad:prepare()
  pad:clear()
  -- Display events
  -- Turn on mixer button
  pad:button(0, 8):setState('Green')

  for row=1,3 do
    for col=1,8 do
      local id = row*16 + col
      local e = events[id]
      if e then
        self:setEventState(e)
      end
    end
  end
  pad:commit()

  local e = event
  if e then
    local id = e.id
    if id then
      local row = math.floor(id/16) + 1
      local col = (id % 16)
      self.event = nil
      self.btn   = nil
      self:editEvent(e, row, col)
    end
  end
end

function lib:press(row, col)
  local f
  if row == 0 then
    f = top_button[col]
  elseif col == 9 then
    f = col_button[row]
  else
    f = grid_button[row]
  end
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

-- Last column buttons
function private:batchButton(row, col)
  local key = PARAMS[row]
  self.lseq:loadView('Batch', key)
end
for i, key in ipairs(PARAMS) do
  if key ~= '' then
    col_button[i] = private.batchButton
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
  if self.copy_event then
    e = self.seq:setEvent(id, self.copy_event)
    e.mute = true
    self.copy_event = nil
    self.copy_btn:setState('Off')
  end
  self:editEvent(e, row, col)
end
grid_button[1] = lib.selectNote
grid_button[2] = lib.selectNote
grid_button[3] = lib.selectNote

function lib:editEvent(e, row, col)
  -- last event
  local le = self.event
  self.event = e
  -- turn off highlight current event
  if self.btn then
    -- current on button
    if le.is_new then
      self.btn:setState(EVENT_LIST[1])
    else
      self:setEventState(le)
    end
  end
  self.btn = self.pad:button(row, col)
  self.pad:prepare()
    self:setEventState(e)
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
      elseif key ~= '' then
        private.loadParam(self, key, e)
      end
    end
  self.pad:commit()
end

function lib:setEventState(e)
  local id = e.id
  local row = math.floor(id/16) + 1
  local col = (id % 16)
  local btn = self.pad:button(row, col)
  local b = 2
  if e.off_t then
    -- NoteOn
    b = 5
  else
    b = 2
  end

  if e == self.event then
    b = b + 1
  elseif e.mute then
    b = 7
  end
  btn:setState(EVENT_LIST[b])
end

function private:copyEvent(row, col)
  if self.copy_event then
    self.copy_event = nil
    self.copy_btn:setState('Off')
  else
    self.copy_event = self.event
    local btn = self.copy_btn
    if not btn then
      btn = self.pad:button(row, col)
      self.copy_btn = btn
    end
    btn:setState('Green')
  end
end
top_button[5] = private.copyEvent

function private:loadBatch(row, col)
  self.lseq:loadView('Batch')
end
top_button[8] = private.loadBatch


for _, key in ipairs(PARAMS) do
  if key ~= '' then
    grid_button[ROW_INDEX[key]] = function(self, row, col)
      private.setParam(self, key, row, col)
    end
  end
end

-- Also used by LBatchView
function private:setParam(key, row, col, e, states)
  local states = states or BIT_STATE
  local seq = self.seq
  local e = e or self.event
  if not e then
    -- Red ?
    return
  end
  local p = e[key]
  local r = BITS[key][col]
  local bits = self.bits[key][row]
  local b = bits[col]
  if type(r) == 'string' then
    -- special operation
    if r == 'mute' then
      self.event = seq:setEvent(e.id, {
        mute = not e.mute
      })
      -- reload event
      local id = e.id
      local row = math.floor(id/16) + 1
      local col = (id % 16)
      self:editEvent(e, row, col)
      return
    else
      -- ignore
      return
    end
  elseif r then
    local tuplet = false
    if r > 1000 then -- tuplet bit
      tuplet = true
      r = r - 1000
    end
    p = p - b * r
    if tuplet then
      -- tuplet bit
      b = (b + 1) % 3
    elseif b == 0 then
      b = 1
    else
      b = 0
    end
    bits[col] = b
    -- if key == 'loop' and seq.global_loop then
    --   -- update global loop
    --   seq:setGlobalLoop(p + b * r)
    -- else
      self.event = seq:setEvent(e.id, {
        [key] = p + b * r,
      })
    --end
  else
    b = 0
  end
  if e.mute then
    self.btns[key][row][col]:setState(states[b+4])
  else
    self.btns[key][row][col]:setState(states[b+1])
  end
end

function private:loadParam(key, e, value, states, row)
  local states = states or BIT_STATE
  local value = value or (e and e[key]) or 0
  local row = row or ROW_INDEX[key]
  local pad = self.pad

  local btns = self.btns[key]
  if not btns then
    btns = {}
    self.btns[key] = btns
  end
  btns = btns[row]
  if not btns then
    btns = {}
    self.btns[key][row] = btns
    for i=1,8 do
      btns[i] = pad:button(row, i)
    end
  end

  local bits = self.bits[key]
  if not bits then
    bits = {}
    self.bits[key] = bits
  end
  bits[row] = {}
  bits = bits[row]
  
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
    elseif r then
      if r > 1000 then
        -- tuplet
        r = r - 1000
      end
      b = math.floor(value / r)
      if key == 'note' and b > 1 then
        b = 1
      end
      value = value - b * r
    else
      b = 0
    end
    bits[i] = b
    if e.mute then
      b = b + 3
    end
    btns[i]:setState(states[b+1])
  end
end

-- Share some private stuff with LBatchView
lib.batch = {
  loadParam = private.loadParam,
  setParam  = private.setParam,
  PARAMS    = PARAMS,
  BIT_STATE = BIT_STATE,
}

