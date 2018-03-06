local game = require("game")
local match_mgr = require "match_mgr"
local skynet = require "skynet"

local match = {}

match.__index = match

function match.new(...)
    local o = {}
    setmetatable(o, match)
    o:init(...)
    return o
end

function match:init(info)
    print("match:init")
    dump(info)
    self.id = info.room_id
    self.room_conf = info.room_conf
    self.player_list = info.player_list
    self.total_score_list = {}
    self.total_rounds = info.rounds
    self.cur_rounds = 0

    self:init_account_2_player_list()
    self:init_account_2_seat_list()
    self.next_ready_list = {}
    self:create_game()
    self.game:begin()
end

function match:init_dispatch_tbl()
    self.dispatch_tbl = {
        ["pdk.ready_next"] = match.on_ready_next
    }
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
        return func(self, seat, content)
    else
        if self.game then
            return self.game:deal_msg(seat, proto_name, content)
        end
    end
end

function match:create_game()
    self.cur_rounds = self.cur_rounds + 1    
    self.game = game.new(#self.player_list, self.room_conf,
        handler(self, self.send_client),
        handler(self, self.send_all_client),
        handler(self, self.send_other_client)
        )
end

function match:on_outside_force_end()
    self:on_match_end(true)
end

function match:on_ready_next(seat, content)
    self.ready_next[seat] = true
    local all_ready = true
    for seat = 1, #self.player_list do
        if not self.ready_next[seat] then
            all_ready = false
        end
    end

    if all_ready then
        self.game:begin(self.last_round_winner)
    end

    self:send_all_client("pdk.ready_next", {ready_seat = seat})
end

function match:get_score_list(winner, card_lists)
    local score_list = {}
    for seat, cards in ipairs(card_lists) do
        if winner ~= seat then
            local score = #cards
            if score == 1 then
                score = 0 
            end
            score_list[seat] = -score
            score_list[winner] = score_list[winner] + score
        end
    end
end

function match:on_match_end(is_force)
    skynet.send("room_mgr", "lua", "on_room_closed", self.id)
    self:send_all_client("pdk.match_end", {rounds = self.cur_rounds, total = self.total_score_list, force = is_force})
    match_mgr.remove(self)
end

function match:on_round_over(over_info)
    local score_list = self:get_score_list(over_info.winner, over_info.cards)
    self.last_round_winner = over_info.winner

    for seat, score in ipairs(score_list) do
        self.total_score_list[seat] = self.total_score_list[seat] + score
    end

    self.game = nil

    if self.cur_rounds >= self.total_rounds then
        self:on_match_end()
    else
        self:send_all_client("pdk.game_end", {rounds = self.cur_rounds, score = score_list, total = self.total_score_list}) 
        self.next_ready_list = {}
    end
end

function match:on_user_login(player_info)
    local player = self.account_2_player_list[player_info.account]
    player.base_app = player_info.base_app

    local seat = self.account_2_seat_list[account]
    if self.game then
        self:send_client(seat, "pdk.game_info", 
            {round = self.cur_rounds, game_context = self.game:pack()})
    else
        self:send_client(seat, "pdk.game_info", 
            {round = self.cur_rounds, ready_list = self.next_ready_list})
    end
end

function match:on_user_offline(account)
    local player = self.account_2_player_list[account]
    player.base_app = nil

    local seat = self.account_2_seat_list[account]
    self.next_ready_list[seat] = nil
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
