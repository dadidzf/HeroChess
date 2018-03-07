local logic = require "logic"
local game = {}

game.__index = game

local _proto_name_map_func_name = {
    ["pdk.out_card"] = "on_out_card",
    ["pdk.pass"] = "on_pass"
}

function game.new(...)
    local o = {}
    setmetatable(o, game)
    game.init(o, ...)
    return o
end

function game:init(player_counts, room_info, send_client_func, send_all_client_func, send_other_client_func)
    self.room_info = room_info
    self.send_client_func = send_client_func
    self.send_all_client_func = send_all_client_func
    self.send_other_client_func = send_other_client_func

    self.player_counts = player_counts
end

function game:register_send_callbacks(send_client_func, send_all_client_func, send_other_client_func)
    self.send_client_func = send_client_func
    self.send_all_client_func = send_all_client_func
    self.send_other_client_func = send_other_client_func
end

function game:register_over_callback(game_over_func)
    self.game_over_func = game_over_func
end

function game:begin(first_seat)
    local card_counts = self.room_info.card_counts or 48
    self.player_hand_cards = logic.shuffle(card_counts)
    assert(card_counts == 15*3 or card_counts == 16*3)

    if first_seat then
        self.cur_seat = first_seat
    else
        self.cur_seat = self:get_first_seat()
    end

    for seat = 1, self.player_counts do
        self:send_client(seat, "pdk.send_card", {cur_seat = self.cur_seat, cards = self.player_hand_cards[seat]})
    end
end

function game:get_first_seat()
    if self.player_counts == 2 then
        return math.random(1, 2)
    else
        dump(self.player_hand_cards)
        for seat, seat_cards in ipairs(self.player_hand_cards) do
            for _, card in ipairs(seat_cards) do
                if card == 0x33 then
                    return seat
                end
            end
        end
    end
end

function game:on_out_card(seat, content)
    if self.cur_seat ~= seat then
        return {errmsg = "not your turn"}
    else
        local out_cards = content.cards
        local result, left_cards = self:check_out_cards(seat, out_cards)

        if result then
            local is_last = not next(left_cards)
            local out_card_info = logic.get_type(out_cards, is_last)

            if self.previous_cards_record then
                local previous_card_info = self.previous_cards_record[#self.previous_cards_record].card_info
                if not logic.is_big(previous_card_info, out_card_info) then
                    return {errmsg = "error out cards"}
                end
            else
                self.previous_cards_record = {}
            end

            table.insert(self.previous_cards_record, 
                {seat = self.cur_seat, card_info = out_card_info, cards = out_cards})
            self.cur_seat = self:next_seat(seat)
            self:send_all_client("pdk.out_card", 
                {cur_seat = self.cur_seat, out_seat = seat, out_cards = out_cards})
            self.player_hand_cards[seat] = left_cards

            if not next(left_cards) then
                self.game_over_func({winner = seat, cards = self.player_hand_cards})
            end
        else
            return {errmsg = "out cards not match with server !"}
        end
    end
end

function game:on_pass(seat, content)
    if self.cur_seat ~= seat then
        return {errmsg = "not your turn"}
    else
        assert(self.previous_cards_record)
        local previous_card_info = self.previous_cards_record[#self.previous_cards_record]
        if logic.is_bigger_cards_exist(previous_card_info.card_info, self.player_hand_cards[seat]) then
            return {errmsg = "can not pass, you have bigger cards !"}
        else
            self.cur_seat = self:next_seat(seat)

            local new_turn = false
            if previous_card_info.seat == self.cur_seat then
                self.previous_cards_record = nil -- new turn
                new_turn = true
            end

            self:send_all_client("pdk.pass", {cur_seat = self.cur_seat, pass_seat = seat, new_turn = new_turn})
        end
    end
end

function game:check_out_cards(seat, out_cards)
    print("game:check_out_cards", seat)
    dump(self.player_hand_cards)
    dump(out_cards)
    local card_set = {}
    for _, card in ipairs(out_cards) do
        card_set[card] = true
    end

    local left_cards = {}
    for _, card in ipairs(self.player_hand_cards[seat]) do
        if card_set[card] then
            card_set[card] = nil
        else
            table.insert(left_cards, card)
        end
    end

    if next(card_set) then
        return false
    else
        return true, left_cards
    end
end

function game:next_seat(seat)
    return seat%self.player_counts + 1
end

function game:pre_seat(seat)
    return (seat + self.player_counts - 2)%self.player_counts + 1
end

function game:pack()
    return {
        cards = self.player_hand_cards,
        cur_seat = self.cur_seat,
        previous_cards_record = self.previous_cards_record
    }
end

function game:deal_msg(seat, proto_name, content)
    local func_name = _proto_name_map_func_name[proto_name]
    if func_name then
        return self[func_name](self, seat, content)
    else
        skynet.error("pdk : can not deal message name - ", proto_name)
        return {errmsg = "can not deal"}
    end
end

function game:send_client(seat, proto_name, msg)
    self.send_client_func(seat, proto_name, msg)
end

function game:send_all_client(proto_name, msg)
    self.send_all_client_func(proto_name, msg)
end

function game:send_other_client(myseat, proto_name, msg)
    self.send_other_client_func(myseat, proto_name, msg)
end

return game