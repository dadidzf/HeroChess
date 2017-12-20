local id_mgr = require "id_mgr"
local room = require "room"
local game_list = require "game_list"

local room_mgr = {}

function room_mgr:init()
    id_mgr:init()

    self.room_tbl = {}
    self.player_2_room = {}

    self.game_2_room = {}
    for game_id, _ in ipairs(game_list) do
        self.game_2_room[game_id] = {}
    end
end

function room_mgr:create(game_id, player_info)
    local room_id = id_mgr:gen_id(game_id)
    room = room.new(room_id, game_id, player_info)
    self.room_tbl[room_id] = room
    self.player_2_room[player_info.account] = room 
    table.insert(self.game_2_room[game_id], room)

    return id
end

function room_mgr:get_room_by_owner(account)
    local room = self.player_2_room[account] 
    if room then
        if room:get_owner() == account then
            return room
        end
    end
end


--[[
    客户端消息响应
--]]
function room_mgr:join(room_id, player_info)
    local room = self.room_tbl[room_id]
    if room then
        if room:is_full() then
            return {errmsg = "room is full"}
        else
            self.player_2_room[player_info.account] = room_id
            return room:join()
        end
    else
        return {errmsg = "room not exist"}
    end
end

function room_mgr:user_ready(account, is_ready)
    local room = self.player_2_room[account] 
    if room then
        room:user_ready(account, is_ready)
    end
end

function room_mgr:dissolve_room(account, is_dissolve)
    local room = self.player_2_room[account] 
    if room then
        room:dissolve_room(account, is_dissolve)
    end
end


--[[
    状态响应
--]]
function room_mgr:on_user_offline(account)
    local room = self.player_2_room[account] 
    if room then
        room:on_user_offline(account)
    end
end

function room_mgr:on_user_login(player_info)
    local room = self.player_2_room[player_info.account]
    if room then
        room:on_user_login(player_info)
    end
end

function room_mgr:on_room_closed(room_id)
    local room = self.room_tbl[room_id] 
    if room then
        room:clear()
        for _, player in ipairs(room:get_player_list()) do
            skynet.send(player.base_app, "lua", "bind_account_2_game", player.account, nil)
            self.player_2_room[player.account] = nil
        end

        self.room_tbl[room_id] = nil
        id_mgr:id_recover(room_id)
    end
end

function room_mgr:on_room_dissolved(room)
    self:on_room_closed(room:get_room_id()) 
end

return room_mgr
