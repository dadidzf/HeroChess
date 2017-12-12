local skynet = require "skynet"
local G = require "global"

local M = {}

M.__index = M

function M.new(...)
    local o = {}
    setmetatable(o, M)
    M.init(o, ...)
    return o
end

function M:init(id, game_id, player_info)
    self.id = id
    self.game_id = game_id
    self.owner_account = player_info.account
    self.player_list = {player_info}
    self.ready = false
    self.getting_area = false
end

function M:add(player_info)
    table.insert(self.player_list, player_info)
    if #self.player_list == 4 then
        print("房间凑齐了四个人")
        self.ready = true
        G.room_mgr:add_ready(self)
    end

    self:send_other_client(#self.player_list, "room.user_enter", {account = player_info.account})
    return self:pack()
end

function M:start()
    print("开启一桌")
    local area = skynet.call("game_mgr", "lua", "get_game", self.game_id)
    self.getting_area = true
    skynet.send(area.addr, "lua", "create_room", self:pack())
end

function M:pack()
    return {
        id = self.id,
        owner_account = self.owner_account,
        player_list = self.player_list
    }
end

function M:send_client(seat, proto_name, msg)
    local player = self.player_list[seat]
    skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
end

function M:send_all_client(proto_name, msg)
    for _, player in ipairs(self.player_list) do
        skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
    end
end

function M:send_other_client(myseat, proto_name, msg)
    local me = self.player_list[myseat]
    for id, player in ipairs(self.player_list) do
        if id ~= myseat then
            skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
        end
    end
end

return M
