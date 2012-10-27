require 'lubyk'
s  = seq.Sequencer()
ls = seq.LSeq(s)
out  = midi.Out()
sync = midi.In()
sync:virtualPort('LSeq')
-- do not ignore midi sync
sync:ignoreTypes(true, false, true)

local t = 0
local last = nil
function sync:receive(msg)
  if msg.type == 'Clock' then
    local op = msg.op
    if op == 'Tick' then
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

function s:playback(e)
  -- Important to trigger so that NoteOff is registered.
  out:send(e:trigger())
end

run()
