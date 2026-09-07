package.path = './?.lua;' .. package.path

package.preload['common'] = function() return true end
package.preload['chat'] = function()
    local function value()
        return { append = function(self) return self end }
    end
    return { header=value, message=value, error=value }
end
package.preload['settings'] = function()
    return {
        load=function(defaults) return defaults end,
        register=function() end,
        save=function() end,
    }
end

local callbacks = {}
local clock_ms = 1000
addon = {}
ashita = {
    time={ clock=function() return { ms=clock_ms } end },
    events={ register=function(kind, _, fn) callbacks[kind]=fn end },
}
T = function(values)
    return setmetatable(values, { __index={ any=function(self, ...)
        for _, value in ipairs({...}) do
            if self[1] == value then return true end
        end
        return false
    end } })
end
bit = require('bit')
ImGuiCond_Always=1
ImGuiWindowFlags_AlwaysAutoResize=1
ImGuiWindowFlags_NoCollapse=2
ImGuiWindowFlags_NoScrollbar=4
ImGuiWindowFlags_NoTitleBar=8
ImGuiWindowFlags_NoInputs=16

local began, ended = 0, 0
local fail_draw = false
local rendered_text = {}
package.preload['imgui'] = function()
    return {
        SetNextWindowPos=function() end,
        SetNextWindowBgAlpha=function() end,
        Begin=function() began=began+1; return true end,
        End=function() ended=ended+1 end,
        TextColored=function(_, text)
            if fail_draw then error('simulated draw failure') end
            table.insert(rendered_text, text)
        end,
        SameLine=function() end,
        TextDisabled=function() end,
        GetWindowPos=function() return 10, 20 end,
    }
end

local stale = true
local native_reads = 0
local gui_reads = 0
local player = {
    GetBuffs=function() native_reads=native_reads+1; return {} end,
    GetExpCurrent=function()
        native_reads = native_reads + 1
        assert(began == ended, 'player memory read occurred inside an open ImGui window')
        if stale then error('simulated stale player during transition') end
        return 500
    end,
    GetExpNeeded=function() native_reads=native_reads+1; return 1000 end,
}
AshitaCore = {
    GetGuiManager=function()
        gui_reads = gui_reads + 1
        return { GetVisible=function() return true end }
    end,
    GetMemoryManager=function()
        native_reads = native_reads + 1
        return { GetPlayer=function() native_reads=native_reads+1; return player end }
    end,
    GetChatManager=function() return { QueueCommand=function() end } end,
}
GetPlayerEntity=function() native_reads=native_reads+1; return { ServerId=1234 } end

require('ExpStats')
callbacks.packet_in({ id=0x00A, data_modified='' })
local ok, err = pcall(callbacks.d3d_present)

assert(ok, 'transition frame escaped an error: ' .. tostring(err))
assert(began == ended, ('ImGui imbalance: Begin=%d End=%d'):format(began, ended))
assert(began == 1, 'transition frame should render from cached Lua state')
assert(native_reads == 0, 'transition render touched player memory')

clock_ms = 4000
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'stale post-transition read escaped an error: ' .. tostring(err))
assert(began == 2 and ended == 2, 'post-transition render should remain balanced')
assert(native_reads == 0, 'post-transition render touched player memory')

stale = false
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'stable frame escaped an error: ' .. tostring(err))
assert(began == 3 and ended == 3, ('stable ImGui imbalance: Begin=%d End=%d'):format(began, ended))
assert(native_reads == 0, 'stable render touched player memory')

fail_draw = true
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'draw failure escaped the callback: ' .. tostring(err))
assert(began == 4 and ended == 4, ('failed-draw ImGui imbalance: Begin=%d End=%d'):format(began, ended))
assert(native_reads == 0, 'failed draw path touched player memory')

local bytes = {}
for index = 1, 26 do bytes[index] = 0 end
local function put_u16(index, value)
    bytes[index] = value % 256
    bytes[index + 1] = math.floor(value / 256) % 256
end
local function put_u32(index, value)
    put_u16(index, value % 65536)
    put_u16(index + 2, math.floor(value / 65536))
end
put_u32(5, 1234)
put_u32(17, 200)
put_u16(25, 8)
callbacks.packet_in({ id=0x02D, data_modified=string.rep('\0', 10) })
assert(native_reads == 0, 'malformed packet touched player memory')

put_u16(25, 7)
callbacks.packet_in({ id=0x02D, data_modified=string.char(unpack(bytes)) })
assert(native_reads == 0, 'non-EXP packet touched player memory')

put_u16(25, 8)
callbacks.packet_in({ id=0x02D, data_modified=string.char(unpack(bytes)) })
assert(native_reads == 6, 'confirmed EXP event should perform one complete snapshot')

fail_draw = false
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'cached EXP render escaped an error: ' .. tostring(err))
assert(native_reads == 6, 'cached EXP render performed another player-memory read')
assert(began == 5 and ended == 5, ('cached ImGui imbalance: Begin=%d End=%d'):format(began, ended))
assert(table.concat(rendered_text, ' '):find('Last: 200', 1, true), 'confirmed EXP amount was not recorded')

put_u32(5, 9999)
put_u32(17, 999)
callbacks.packet_in({ id=0x02D, data_modified=string.char(unpack(bytes)) })
rendered_text = {}
callbacks.d3d_present()
assert(not table.concat(rendered_text, ' '):find('Last: 999', 1, true), 'foreign actor EXP was recorded')

local begins_before_logout = began
local native_before_logout = native_reads
local gui_before_logout = gui_reads
callbacks.packet_in({ id=0x00B, data_modified='' })
callbacks.d3d_present()
assert(began == begins_before_logout, 'logout frame opened an ImGui window')
assert(native_reads == native_before_logout, 'logout frame touched player memory')
assert(gui_reads == gui_before_logout, 'logout frame touched the GUI manager')

callbacks.packet_in({ id=0x00A, data_modified='' })
callbacks.d3d_present()
assert(began == begins_before_logout + 1, 'zone-enter packet did not resume rendering')
print('PASS: d3d_present renders cached state without player-memory reads')
