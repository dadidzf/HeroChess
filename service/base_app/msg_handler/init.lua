local sock_mgr = require "sock_mgr"
local msg_define = require "msg_define"
local room = require ("msg_handler.room")
local game = require ("msg_handler.game")

local M = {}

function M.init_room_handler()
    for func_name, func in pairs(room) do
        sock_mgr:register_callback("room."..func_name, func)
    end
end

function M.init_game_handler()
    for _, name in ipairs(msg_define.getAllGameProtos()) do
        sock_mgr:register_callback(name, function(...) return game.deal_msg(name, ...) end)
    end
end

function M.init()
    M.init_room_handler()
    M.init_game_handler()
end

return M
