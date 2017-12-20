local sock_mgr = require "sock_mgr"
local player = require "player"
local player_mgr = require "player_mgr"
local skynet = require "skynet"

local login_mgr = {}

function login_mgr:init()
    sock_mgr:register_callback("login.login_baseapp", handler(self, self.auth))
end

function login_mgr:auth(fd, msg)
    if msg.token ~= "token" then
        return {errmsg = "wrong token"}
    else
        sock_mgr:auth_fd(fd)

        local player = player.create(fd, msg.account)
        player:load_from_db()
        player_mgr:add(player)
        sock_mgr:send(fd, "login.login_baseapp", {info = player:pack()})

        skynet.send("base_app_mgr", "lua", "bind_account_2_baseapp", msg.account, skynet.self())
        skynet.send("room_mgr", "lua", "on_user_login", {base_app = skynet.self(), account = player:get_account()})
    end
end

return login_mgr
