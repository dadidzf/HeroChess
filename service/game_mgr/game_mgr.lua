local skynet = require "skynet"
local game_list = require "game_list"

local M = {}

function M:init()
    self.game_tbl = {}
    self:create_game_by_list()
end

function M:create_game_by_list()
    for id, v in ipairs(game_list) do
        local addr = skynet.newservice(v.service, id)
        self.game_tbl[id] = {addr = addr}
    end
end

function M:get_game(game_id)
    return self.game_tbl[game_id]
end

return M
