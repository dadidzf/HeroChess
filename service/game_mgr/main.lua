-- 每个area是一个赛场，本服务是赛场管理器
local skynet = require "skynet"
require "skynet.manager"
local game_mgr = require "game_mgr"

local CMD = {}

function CMD.start()
    game_mgr:init()
end

function CMD.get_game(game_id)
    return game_mgr:get_game(game_id)
end

local function dispatch(_, session, cmd, ...)
    local f = CMD[cmd]
    assert(f, "game_mgr接收到非法lua消息: ".. tostring(cmd))

    if session == 0 then
        f(...)
    else
        skynet.ret(skynet.pack(f(...)))
    end
end

skynet.start(function ()
    skynet.dispatch("lua", dispatch)

    skynet.register("game_mgr")

    skynet.error("game_mgr booted...")
end)
