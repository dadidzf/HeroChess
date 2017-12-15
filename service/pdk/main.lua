local skynet = require "skynet"
local player_mgr = require "player_mgr"
local match = require "match"
local match_mgr = require "match_mgr"

local id = tonumber(...)

local CMD = {}

function CMD.create_game(info)
    local obj = match.new(info)
    match_mgr:add(obj)
end

function CMD.dissolve_game(room_info)
    match_mgr:remove_by_id(room_info.room_id)
end

function CMD.on_user_offline(info)
    local id = info.room_id
    local account = info.account
    local match = match_mgr:get(id)
    match:on_user_offline(account)
end

function CMD.on_user_login(info)
    local id = info.room_id
    local player_info = info.player_info
    local match = match_mgr:get(id)
    match:on_user_login(player_info)
end

function CMD.deal_game_msg(msg)
    local match = match_mgr:get(msg.id)
    return match.deal_msg(msg.proto_name, msg.content)
end

skynet.start(function ()
    skynet.dispatch("lua", function (_, session, cmd, ...)
        local f = CMD[cmd]
        assert(f, cmd)

        if session == 0 then
            f(...)
        else
            skynet.ret(skynet.pack(f(...)))
        end
    end)

    match_mgr:init()
end)
