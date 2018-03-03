local skynet = require "skynet"
local G = require "global"
local game_list = require "game_list"

local room = {}

room.__index = room

function room.new(...)
    local o = {}
    setmetatable(o, room)
    room.init(o, ...)
    return o
end

function room:init(room_id, game_id, player_info, room_conf)
    self.room_id = room_id
    self.game_id = game_id
    self.room_conf = room_conf

    self.owner_account = player_info.account
    self.player_list = {player_info}
    self.account_2_player = {}
    self.account_2_player[self.owner_account] = player_info

    self.online_list = {}
    self.ready_list = {}
    self.dissolve_list = {}
    self.online_list[self.owner_account] = true

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
    if self.game_conf.min_player_counts <= #self.player_list then
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
    self:send_all_client("room.user_ready", {account = account,  is_ready = is_ready})

    if self:check_ready() then
        room:start()
    end
end

function room:dissolve_room(account, is_dissolve)
    if self.game then
        if next(self.dissolve_list) then
            if is_dissolve then
                table.insert(self.dissolve_list, account)
                local will_dissolve = true 
                for account, _ in ipairs(self.online_list) do
                    if not self.dissolve_list[account] then
                        will_dissolve = false
                    end
                end
                if will_dissolve then
                    self:send_all_client("room.dissolve_room", {dissolve = true})
                    self.dissolve_list = {}
                    skynet.send(self.game.addr, "lua", "dissolve_game", {room_id = self.room_id})
                    G.room_mgr:on_room_dissolved(self)
                end
            else
                self:send_all_client("room.dissolve_room", {dissolve = false})
            end
        else
            if is_dissolve then
                self.dissolve_list[account] = true
                self:send_all_client("room.dissolve_room", self.dissolve_list)
            end
        end
    else
        if account == self.owner_account and is_dissolve == true then
            self.dissolve_list = {}
            self:send_all_client("room.dissolve_room", {dissolve = true})
            G.room_mgr:on_room_dissolved(self)
        else
            self:send_client(account, "room.dissolve_room", {errmsg = "must be owner"})
        end
    end
end

function room:on_user_login(player_info)
    if self.game then
        skynet.send(player_info.base_app, "lua", "bind_account_2_game", 
            player.account, {game = room:get_game(), id = room_id})

        self:send_client(player_info.account, "system.game_reconnect", 
            {room_id = self.room_id, game_id = self.game_id})

        self:send_client(player_info.account, "room.room_info", self:pack())
        self:send_other_client("room.user_enter", {account = player_info.account})
        skynet.send(self.game.addr, "lua", "on_user_login", 
            {room_id = self.room_id, player_info = player_info})
    end
end

function room:on_user_offline(account)
    self.ready_list[account] = nil
    self.online_list[account] = nil

    self:send_other_client(account, "room.user_exit", {account = account})
    self.account_2_player[account] = nil

    if self.game then
        skynet.send(self.game.addr, "lua", "on_user_offline", {room_id = self.room_id, account = account})
    else
        local index_to_remove
        for index, player in ipairs(self.player_list) do
            if player.account == account then
                index_to_remove = index
            end
        end

        self.player_list[index_to_remove] = nil
    end
end

function room:join(player_info)
    table.insert(self.player_list, player_info)
    self.account_2_player[player_info.account] = player_info
    room:send_other_client(player_info.account, "room.user_enter", {account = player_info.account})
    return room:pack()
end

function room:start()
    self.game = skynet.call("game_mgr", "lua", "get_game", self.game_id)
    skynet.send(game.addr, "lua", "create_game", 
        {room_id = self.room_id, player_list = self.player_list, room_conf = self.room_conf})
end

function room:pack()
    return {
        room_id = self.room_id,
        room_conf = self.room_conf,
        owner_account = self.owner_account,
        player_list = self.player_list,
        online_list = self.online_list,
        ready_list = self.ready_list
    }
end

function room:send_client(account, proto_name, msg)
    local player = self.account_2_player[account] 
    skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
end

function room:send_all_client(proto_name, msg)
    for _, player in ipairs(self.player_list) do
        skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
    end
end

function room:send_other_client(account, proto_name, msg)
    for _, player in ipairs(self.player_list) do
        if account ~= player.account then
            skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
        end
    end
end

function room:clear()
end

return room
