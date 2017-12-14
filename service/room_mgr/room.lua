local skynet = require "skynet"
local G = require "global"
local game_list = require "game_list"

local room = {}

room.__index = room

function room.new(...)
    local o = {}
    setmetatable(o, M)
    M.init(o, ...)
    return o
end

function room:init(room_id, game_id, player_info)
    self.room_id = room_id
    self.game_id = game_id

    self.owner_account = player_info.account
    self.player_list = {player_info}
    self.player_2_index = {}
    self.player_2_index[player_info.account] = 1
    self.ready_list = {}
    self.dissolve_list = {}

    self.game_conf = game_list[self.game_id]
    self.min_player_counts = self.game_conf.min_player_counts
    self.max_player_counts = self.game_conf.max_player_counts
end

function room:get_room_id()
    return self.room_id
end

function room:get_owner()
    return self.owner_account
end

function room:get_game()
    return self.game
end

function room:get_player_list()
    return self.player_list
end

function room:check_ready()
    if self.game_conf.min_player_counts == #self.player_list then
        for _, player_info in ipairs(self.player_list) do
            if self.ready_list[player_info.account] ~= true then
                return false
            end
        end

        return true
    end
end

function room:is_full()
    return #self.player_list >= self.max_player_counts
end

function room:user_ready(account, is_ready)
    self.ready_list[account] = is_ready
    self:send_all_client("room.user_ready", {account = is_ready})

    if self:check_ready() then
        room:start()
    end
end

function room:dissolve_room(account, is_dissolve)
    if next(self.dissolve_list) then
        if is_dissolve then
            table.insert(self.dissolve_list, account)
            if #self.player_list == #self.dissolve_list then
                self:send_all_client("room.dissolve_room", {dissolve = true})
                skynet.send(self.game.addr, "lua", "dissolve_game", {room_id = self.room_id})
                G.room_mgr:on_room_dissolved(self)
            end
        else
            self:send_all_client("room.dissolve_room", {dissolve = false})
        end
    else
        if is_dissolve then
            table.insert(self.dissolve_list, account)
            self:send_all_client("room.dissolve_room", self.dissolve_list)
        end
    end
end

function room:on_user_login(player_info)
    assert(self.player_2_index[player_info.account] == nil, "room:on_user_login -- user is alreay in room")
    self:add(player_info)
    skynet.send(self.game.addr, "lua", "on_user_login", {room_id = self.room_id, player_info = player_info})
end

function room:on_user_offline(account)
    self.ready_list[account] = nil
    local player_index = self.player_2_index[account]
    self.player_2_index[account] = nil
    assert(player_index)

    local len = #self.player_list
    local last_player = self.player_list[len]
    self.player_list[player_index]  = last_player
    self.player_list[len] = nil
    self.player_2_index[last_player.account] = player_index
    skynet.send(self.game.addr, "lua", "on_user_offline", {room_id = self.room_id, account = account})
end

function room:add(player_info)
    self.player_2_index[player_info.account] = #self.player_list
    table.insert(self.player_list, player_info)
end

function room:start()
    self.game = skynet.call("game_mgr", "lua", "get_game", self.game_id)
    skynet.send(game.addr, "lua", "create_game", self:pack())
end

function room:pack()
    return {
        room_id = self.room_id,
        owner_account = self.owner_account,
        player_list = self.player_list
    }
end

function room:send_client(seat, proto_name, msg)
    local player = self.player_list[seat]
    skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
end

function room:send_all_client(proto_name, msg)
    for _, player in ipairs(self.player_list) do
        skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
    end
end

function room:send_other_client(myseat, proto_name, msg)
    local me = self.player_list[myseat]
    for id, player in ipairs(self.player_list) do
        if id ~= myseat then
            skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
        end
    end
end

function room:clear()
end

return room
