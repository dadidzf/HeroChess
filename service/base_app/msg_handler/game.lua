local skynet = require "skynet"
local player_mgr = require "player_mgr"

local game = {}

function game.deal_msg(name, fd, request)
    local player = player_mgr:get_by_fd(fd)
    local game_info = player_mgr:get_game_info(player.account)

    if game_info.game and game_info.id then
        print("game.deal_msg")
        dump(game_info)
        return skynet.call(game_info.game.addr, "lua", "deal_game_msg", player.account, {proto_name = name, id = game_info.id, content = request})
    end
end

return game
