require 'lubyk'
s  = seq.Sequencer()
s.channel = 1
ls = seq.LSeq(s)
out = midi.Out()
sync = midi.In()
sync:virtualPort('LSeq')
-- do not ignore midi sync
sync:ignoreTypes(true, false, true)

local t = 0
local last = nil
local ms_per_tick = 1
function sync:receive(msg)
  if msg.type == 'Clock' then
    local op = msg.op
    if op == 'Tick' then
      t = t + 1
      if last then
        local l = now()
        -- no smoothing, nothing
        ms_per_tick = l - last
        last = l
      else
        ms_per_tick = 60000 / 124 / 24 -- consider 120 bpm
      end

      list = s.list
      local e = list.next
      while e and e.t <= t do
        s:trigger(e)
        e = list.next
      end
    elseif op == 'Start' then
      -- Next tick = beat 0
      t = -1
    elseif op == 'Song' then
      t = msg.position - 1
      s:buildActiveList(msg.position)
    end
  end
end

out:virtualPort('LSeq')
-- Called on trigger
function s:playback(e)
  out:sendNote(1, e.note, e.velocity, e.length * ms_per_tick)
end

ls:loadView('Main')  

run()
