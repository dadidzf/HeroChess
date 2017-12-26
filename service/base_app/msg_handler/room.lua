local skynet = require "skynet"
local player_mgr = require "player_mgr"

local room = {}

function room.create_room(fd, request)
    local player = player_mgr:get_by_fd(fd)
    local id = skynet.call("room_mgr", "lua", "create_room", request.game_id, 
        {base_app = skynet.self(), account = player:get_account()}, room_conf = request.room_conf)
    return {room_id = id}
end

function room.join_room(fd, request)
    local player = player_mgr:get_by_fd(fd)
    local room_id = request.room_id
    local player_list = skynet.call("room_mgr", "lua", "join_room", room_id, {base_app = skynet.self(), account = player:get_account()})
    return player_list
end

function room.user_ready(fd, request)
    local player = player_mgr:get_by_fd(fd)
    skynet.send("room_mgr", "lua", "user_ready", player.account, request.is_ready)
end

function room.dissolve_room(fd, request)
    local player = player_mgr:get_by_fd(fd)
    skynet.send("room_mgr", "lua", "dissolve_room", player.account, request.is_dissolve)
end

return room
