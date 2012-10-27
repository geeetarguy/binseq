require 'lubyk'
s  = seq.Sequencer()
ls = seq.LSeq(s)
out  = midi.Out()
midiin = midi.In()
midiin:virtualPort('LSeq')
-- do not ignore midi sync
midiin:ignoreTypes(true, false, true)

local t = 0
local last = nil
local running = true
function midiin:receive(msg)
  if msg.type == 'Clock' then
    local op = msg.op
    if running and op == 'Tick' then
      t = t + 1
      if last then
        local l = now()
        -- no smoothing, nothing
        last = l
      end

      list = s.list
      local e = list.next
      while e and e.t <= t do
        s:trigger(e)
        e = list.next
      end
    elseif op == 'Continue' and not running then
      -- Next tick = beat 0
      running = true
    elseif op == 'Start' and not running then
      -- Next tick = beat 0
      t = 0
      s:buildActiveList(t)
      running = true
    elseif op == 'Stop' and running then
      running = false
    elseif op == 'Song' then
      t = msg.position
      if s.partition then
        s:buildActiveList(msg.position)
      end
    end
  else
    ls:record(msg)
  end
end

out:virtualPort('LSeq')

function s:playback(e)
  -- Important to trigger so that NoteOff is registered.
  out:send(e:trigger())
end

run()
