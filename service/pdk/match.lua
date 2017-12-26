local game = require("game")
local match = {}

match.__index = match

function match:new(...)
    local o = {}
    setmetatable(o, match)
    match:init(o, ...)
    return o
end

function match:init(info)
    self.id = info.room_id
    self.room_conf = info.room_conf
    self.player_list = info.player_list
    self.total_score_list = {}
    self.total_rounds = info.rounds
    self.cur_rounds = 0

    self.dispatch_tbl = {}
    self:init_account_2_player_list()
    self:init_account_2_seat_list()
    self:create_game()
end

function match:init_account_2_player_list()
    self.account_2_player_list = {}
    for _, player in ipairs(self.player_list) do
        self.account_2_player_list[player.account] = player
    end
end

function match:init_account_2_seat_list()
    self.account_2_seat_list = {}
    for seat, player in ipairs(self.player_list) do
        self.account_2_seat_list[player.account] = seat
    end
end

function match:deal_msg(account, proto_name, content)
    local seat = self.account_2_seat_list[account]
    local func = self.dispatch_tbl[proto_name]
    if func then
        return func(seat, content)
    else
        if self.game then
            return self.game:deal_msg(seat, proto_name, content)
        end
    end
end

function match:create_game()
    self.cur_rounds = self.cur_rounds + 1    
    self.game = game:new(#self.player_list, self.room_conf
        handler(self, self.send_client),
        handler(self, self.send_all_client),
        handler(self, self.send_other_client)
        )

    self.game:begin()
end

function match:on_outside_force_end()
    self:send_all_client("pdk.game_end", self.total_score_list)
end

function match:on_round_over(over_info)
    local winner = over_info.cards
    local score_list = {}
    for seat, cards in ipairs(cards_list) do
        if winner ~= seat then
        local score = #cards
        if score == 1 then
            score = 0 
        end
        score_list[seat] = score
        score_list[winner] = score_list[winner] + score
    end

    for seat, score in ipairs(score_list) do
        self.total_score_list[seat] = self.total_score_list[seat] + score
    end

    if self.cur_rounds >= self.total_rounds then
        skynet.send("room_mgr", "lua", "on_room_closed", self.id)
        self:send_all_client("pdk.match_end", self.total_score_list)
    else
        self:send_all_client("pdk.game_end", {score_list, self.total_score_list}) 
        self.next_ready_list = {}
    end
end

function match:on_user_login(player_info)
    local player = self.account_2_player_list[player_info.account]
    player.base_app = player_info.base_app
end

function match:on_user_offline(account)
    local player = self.account_2_player_list[account]
    player.base_app = nil
end

function match:send_client(seat, proto_name, msg)
    local player = self.player_list[seat]
    if player.base_app then
        skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
    end
end

function match:send_all_client(proto_name, msg)
    for _, player in ipairs(self.player_list) do
        if player.base_app then
            skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
        end
    end
end

function match:send_other_client(myseat, proto_name, msg)
    local me = self.player_list[myseat]
    for id, player in ipairs(self.player_list) do
        if id ~= myseat then
            if player.base_app then
                skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
            end
        end
    end
end

return match
