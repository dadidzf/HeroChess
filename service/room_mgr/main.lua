local skynet = require "skynet"
require "skynet.manager"
local G = require "global"
local room_mgr = require "room_mgr"
local timer_mgr = require "timer_mgr"

local function init()
    G.timer_mgr = timer_mgr.new()
    G.room_mgr = room_mgr
    room_mgr:init()

    --G.room_timer = G.timer_mgr:add(1*1000, -1, function() room_mgr:check_ready() end)
end

local CMD = {}

function CMD.create_room(game_id, player_info, room_conf)
    return room_mgr:create(game_id, player_info, room_conf)
end

function CMD.join_room(room_id, player_info)
    return room_mgr:join(room_id, player_info)
end

function CMD.on_user_offline(account)
    return room_mgr:on_user_offline(account)
end

function CMD.on_user_login(player_info)
    return room_mgr:on_user_login(player_info)
end

function CMD.user_ready(account, is_ready)
    return room_mgr:user_ready(account, is_ready)
end

function CMD.dissolve_room(account, is_dissolve)
    return room_mgr:dissolve_room(account, is_dissolve)
end

function CMD.close_room(room_id)
    return room_mgr:on_room_closed(room_id)
end

local function dispatch(_, session, cmd, ...)
    local f = CMD[cmd]
    assert(f, "room_mgr接收到非法lua消息: ".. tostring(cmd))

    if session == 0 then
        f(...)
    else
        skynet.ret(skynet.pack(f(...)))
    end
end

skynet.start(function ()
    skynet.dispatch("lua", dispatch)

    init()

    skynet.register("room_mgr")

    skynet.error("room_mgr booted...")
end)
