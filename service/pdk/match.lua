local mjlib = require "base.mjlib"
local utils = require "utils"

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
    self.player_list = info.player_list

    self.cards = {}

    self.active_seat = 1
    self.players = {}
    for i=1,4 do
        self.players[i] = self:init_player(i)
    end

    utils.print(self.players)
end

function match:deal_msg(proto_name, content)
end

function match:init_player(i)
    local info = {
        seat = i,
        stand_cards = {},
        waves = {},
        active = false,
    }
    return info
end

function match:begin()
    -- 洗牌
    self.cards = mjlib.create(true)
    self.cards_num = #self.cards
    -- 每人发13张牌
    for i=1,4 do
        self:dealt_card(self.players[i].stand_cards, 13)
    end
    self.status = "dealt"

    for i=1,4 do
        local msg = {
            cards = self.players[i].cards
        }
        self.room:send_client(i, "match.dealt", msg)
    end
end

function match:dealt_card(tbl, num)
    self.cards_num = self.cards_num - num
    for _=1,34 do
        table.insert(tbl, 0)
    end

    for i=1,num do
        local index = self.cards[self.cards_num + i]
        tbl[index] = tbl[index] + 1
    end
end

function match:get_card()
    local player = self.players[self.active_seat]

    local card = self.cards[self.card_num]
    player.stand_card[card] = player.stand_card[card] + 1
    self.card_num = self.card_num - 1
end

function match:out_card(card)
    local player = self.players[self.active_seat]
    player.stand_card[card] = player.stand_card[card] - 1
    self.status = "out_card"
end

function match:on_user_login(player_info)
end

function match:on_user_offline(account)
end

function match:send_client(seat, proto_name, msg)
    local player = self.player_list[seat]
    skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
end

function match:send_all_client(proto_name, msg)
    for _, player in ipairs(self.player_list) do
        skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
    end
end

function match:send_other_client(myseat, proto_name, msg)
    local me = self.player_list[myseat]
    for id, player in ipairs(self.player_list) do
        if id ~= myseat then
            skynet.send(player.base_app, "lua", "sendto_client", player.account, proto_name, msg)
        end
    end
end

return match
