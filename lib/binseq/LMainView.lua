--[[------------------------------------------------------

  binseq.LMainView
  ----------------

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
local lib = {type = 'binseq.LMainView', name = 'Main'}
lib.__index         = lib
binseq.LMainView       = lib
-- Last column operation to function
local col_button    = {}
-- Map row operation to function
local grid_button   = {}
-- Buttons used to select events.
local select_note   = {}
-- Map top buttons
local top_button    = {}
-- Map row operation to function
local private       = {}

--=============================================== CONSTANTS
local PARAMS =       {'', '', '',     'note', 'velocity', 'length', 'position', 'loop'}
local EXTRA_PARAMS = {'', '', 'ctrl', 'note', 'velocity', 'length', 'position', 'loop'}
local POS = {
  -- top buttons
  SONG   = 1,
  PAGE   = 2,
  EXTRA  = 3,
  COPY   = 4,
  TOGGLE = 5,
  -- midi ?
  PATTERN_INFO = 7,
  MIXER  = 8,

  -- column buttons
  SEQ  = 1,
  MAIN = 2,
}
local PLURALIZE = {
  note     = 'notes',
  velocity = 'velocities',
  length   = 'lengths',
}
local ROW_INDEX = {}
for i, k in ipairs(EXTRA_PARAMS) do
  if k ~= '' then
    ROW_INDEX[k] = i
  end
end
local posidToGrid = binseq.Event.posidToGrid
local gridToPosid = binseq.Event.gridToPosid

local BITS = {
  ctrl = {
    '',
    64,
    32,
    16,
    8,
    4,
    2,
    1,
  },
  note     = {
    'mute',
    4*12, -- 4 octaves
    2*12, -- 2 octaves
    12,   -- octave
    8,    -- 6th minor (Perfect fifth + half tone)
    4,    -- major third
    2,    -- tone
    1,    -- half tone

    -- Special case if 'extra' field
    extra = {
      'mute',
      64,
      32,
      16,
      8,
      4,
      2,
      1,
    },
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
    1288,  -- 3 whole notes   OOO, OOOOOO
    1096,  -- 1 whole note    O, OO
    48,    -- half note       o
    24,    -- quarter note    .
    12,    -- eighth note     x
    6,     -- 16th note       xx
    3,     -- 32th note       xxx
    1001,   -- 1 tuplet, 2 tuplet
  },
  position = { -- Adding 1000 = triple mode: 0, 1, 2
    1288,  -- 3 whole notes   OOO, OOOOOO
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
    1288,  -- 3 whole notes   OOO, OOOOOO
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
  'LightAmber',
  'LightGreen', -- loaded
  '', -- Never occurs (cannot have NoteOn of inexistant event)
  'Amber', -- NoteOn
  'Green', -- NoteOn on loaded
  'LightRed', -- muted
}
--=============================================== PUBLIC
setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

-- binseq.LMainView(...)
function lib.new(lseq, song)
  local self = {
    lseq = lseq,
    pad  = lseq.pad,
    song = song,
    -- direct access to buttons (ex: btns.position[col])
    btns = {},
    -- direct access to bit values (ex: bits.position[col])
    bits = {},
    -- default pagination
    page = 0,
  }
  return setmetatable(self, lib)
end

-- Display view content (called on load)
function lib:display(key, opt)
  if opt == 'extra' then
    self.extra = not self.extra
  end

  local pad = self.pad
  local song = self.song
  local page = self.page
  -- Clear
  pad:prepare()
  -- Turn on main button
  for col=1,8 do
    if col == POS.EXTRA and self.extra then
      pad:button(0, col):setState('Amber')
    else
      pad:button(0, col):setState('Off')
    end
  end

  for row=1,8 do
    if row == POS.MAIN then
      pad:button(row, 9):setState('Amber')
    else
      pad:button(row, 9):setState('Off')
    end
  end

  local events = song.edit_pattern.events

  local max = 3
  if self.extra then max = 2 end

  select_note = {}

  -- Display events
  for row=1,max do
    select_note[row] = lib.selectNote

    for col=1,8 do
      local posid = gridToPosid(row, col, page)
      local e = events[posid]
      if e then
        self:setEventState(e)
      else
        pad:button(row, col):setState('Off')
      end
    end
  end

  -- editEvent also does a prepare/commit so we must commit before
  pad:commit()

  local e = self.event
  if e then
    local posid = e.posid
    if posid then
      local row, col = posidToGrid(posid, page, max)
      self.event = nil
      if row then
        self.btn   = nil
        self:editEvent(e, row, col)
      end
    end
  else
    for row=max+1,8 do
      for col=1,8 do
        pad:button(row, col):setState('Off')
      end
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
    f = select_note[row] or grid_button[row]
  end
  if f then
    f(self, row, col)
  else
    self.lseq:press(row, col)
  end
end

function lib:selectNote(row, col)
  local posid = gridToPosid(row, col, self.page)
  local e = self.song.edit_pattern:getOrCreateEvent(posid)

  if self.copy_on then
    if self.event then
      e = self.seq:setEvent(posid, self.event)
      e.mute = 1
    else
      return
    end
    self.copy_on = false
    self.copy_btn:setState('Off')
  elseif self.del_on == e.posid then
    -- delete
    self.del_on = false
    self.pad:button(0, 5):setState('Off')

    self.seq.pattern:deleteEvent(e)
    self.pad:button(row, col):setState('Off')
    if e == self.event then
      -- clear
      self.event = nil
      self.btn   = nil
      self:display()
    end
    return
  elseif self.del_on then
    self.del_on = e.posid
    self.pad:button(row, col):setState('Red')
    return
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
    self:setEventState(le)
  end
  self.btn = self.pad:button(row, col)
  self.pad:prepare()
    self:setEventState(e)
    -- Load event state in rows 4 to 8
    local params = self.extra and EXTRA_PARAMS or PARAMS
    for _, key in ipairs(params) do
      if key ~= '' then
        private.loadParam(self, key, e)
      end
    end
  self.pad:commit()
end

function lib:setEventState(e)
  local pat = e.pat
  if pat ~= self.song.edit_pattern then
    return
  end
  local posid = e.posid
  local row, col = posidToGrid(posid, self.page, 3)
  if not row then
    return
  end
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
  elseif e.mute == 1 then
    b = 7
  end
  btn:setState(EVENT_LIST[b])
end

function lib:eventChanged(e)
  if e == self.event then
    self.editEvent(e)
  end
end

function private:copyDelEvent(row, col)
  if self.copy_on then
    self.copy_on = nil
    self.del_on = true
    self.copy_btn:setState('Red')
  elseif self.del_on then
    self.del_on = nil
    self.copy_btn:setState('Off')
  else
    self.copy_on = true
    local btn = self.copy_btn
    if not btn then
      btn = self.pad:button(row, col)
      self.copy_btn = btn
    end
    btn:setState('Green')
  end
end
top_button[POS.COPY] = private.copyDelEvent

for _, key in ipairs(EXTRA_PARAMS) do
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

  local p
  if self.list then
    p = self.list[row]
  else
    p = e[key] or 0
  end
  local r = BITS[key]
  if self.extra or e.ctrl then
    -- Other bit values if extra or ctrl is on.
    r = r.extra or r
  end
  r = r[col]
  local bits = self.bits[key][row]
  if bits == 'multi' then
    -- TODO: Same as BatchView
    print('TODO')
    return
  end

  local b = bits[col]
  if type(r) == 'string' then
    -- special operation
    if r == 'mute' then
      e:set {
        mute = e.mute == 1 and 0 or 1
      }
      -- reload event
      local posid = e.posid
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
    if self.list then
      self.list[row] = p + b * r
      self.list_e:save()
    else
      print('SET', key, p + b * r)
      e:set {
        [key] = p + b * r,
      }
    end
    --end
  else
    b = 0
  end
  if e.mute == 1 then
    self.btns[key][row][col]:setState(states[b+4])
  else
    self.btns[key][row][col]:setState(states[b+1])
  end
end

function private:loadParam(key, e, value, states, row)
  local list = e[PLURALIZE[key]]
  local row = row or ROW_INDEX[key]
  if not self.list and list then
    -- Not in value list mode and event as list
    private.loadList(self, key, e, list, row)
    return
  end
  local states = states or BIT_STATE
  local value = value or (e and e[key]) or 0
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
    local r = BITS[key]
    if self.extra or e.ctrl then
      -- Other bit values if extra or ctrl is on.
      bit_values = bit_values.extra or bit_values
    end
    local r = bit_values[i]
    local b
    if type(r) == 'string' then
      if r == 'mute' then
        b = e.mute == 1 and 3 or 0
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
    if e.mute == 1 then
      b = b + 3
    end
    btns[i]:setState(states[b+1])
  end
end

function private:loadList(key, e, list, row)
  local pad = self.pad
  local idx = e.index[key]
  local b = self.bits[key]
  if not b then
    b = {}
    self.bits[key] = b
  end
  b[row] = 'multi'
  for i = 1,8 do
    if list[i] then
      if i == idx then
        pad:button(row, i):setState('Green')
      else
        pad:button(row, i):setState('LightGreen')
      end
    else
      pad:button(row, i):setState('Off')
    end
  end
end

-- Share some private stuff with LBatchView and LPresetView
-- TODO: move this into LSeq
lib.common = {
  loadParam  = private.loadParam,
  setParam   = private.setParam,
  PARAMS     = PARAMS,
  BIT_STATE  = BIT_STATE,
  EVENT_LIST = EVENT_LIST,
  PLURALIZE  = PLURALIZE,
  POS        = POS,
}

