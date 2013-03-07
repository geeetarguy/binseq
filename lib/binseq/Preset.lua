--[[------------------------------------------------------

  binseq.Preset
  -------------

  A Preset contains activation settings for a song's patterns.

--]]------------------------------------------------------
local lib = {type = 'binseq.Preset'}
lib.__index      = lib
binseq.Preset    = lib
local private    = {}

--=============================================== PUBLIC
setmetatable(lib, {__call = function(lib, ...) return lib.new(...) end})

-- binseq.Preset(...)
function lib.new(def)
  local self = {
    -- Active patterns by posid
    patterns = {},
  }

  setmetatable(self, lib)
  if def then
    if def.song then self:setFromSong(def.song)
    elseif def.data then self:setFromData(def.data)
    end
  end

  return self
end

-- This is used to create a preset from a song's current pattern activation
-- state.
function lib:setFromSong(song)
  local patterns = {}
  self.patterns  = patterns
  for posid, pat in pairs(song.patterns) do
    if pat.seq then
      -- We store pattern id so that if the pattern is deleted a recreated, we
      -- do not activate it.
      patterns[posid] = pat.id
    end
  end
end

-- This is used to create a preset from a song's current pattern activation
-- state.
function lib:setFromData(data)
  local patterns = {}
  self.patterns  = patterns

  for posid, pat_id in pairs(data.patterns) do
    patterns[tonumber(posid)] = pat_id
  end
end

function lib:dump()
  local data = {patterns = {}}
  local patterns = data.patterns
  for posid, pat_id in pairs(self.patterns) do
    patterns[tostring(posid)] = pat_id
  end
  return data
end

