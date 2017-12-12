local sock_mgr = require "sock_mgr"
local player = require "player"
local player_mgr = require "player_mgr"

local M = {}

function M:init()
    sock_mgr:register_callback("login.login_baseapp", handler(self, self.auth))
end

function M:auth(fd, msg)
    if msg.token ~= "token" then
        return {errmsg = "wrong token"}
    else
        sock_mgr:auth_fd(fd)
    end

    local obj = player.create(fd, msg.account)
    obj:load_from_db()

    player_mgr:add(obj)
    return {info = obj:pack()}
end

return M
