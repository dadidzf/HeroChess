local logic = require "logic"
local game = {}

game.__index = game

local _proto_name_map_func_name = {
    "" = "",
}

function game:new()
    local o = {}
    setmetatable(o, game)
    game:init(o, ...)
    return o
end

function game:init(player_counts, send_client_func, send_all_client_func, send_other_client_func)
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

function game:begin()
end

function game:deal_msg(proto_name, content)
    local func_name = _proto_name_map_func_name[proto_name]
    if func_name then
        return self[func_name](content)
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