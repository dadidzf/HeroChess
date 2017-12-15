require "my_init"
local skynet = require "skynet"
local db = require "db"
local sock_mgr = require "sock_mgr"
local player_mgr  = require "player_mgr"
local login_mgr = require "login_mgr"
local msg_handler = require "msg_handler.init"

local CMD = {}

function CMD.start(conf)
    db:init()
    sock_mgr:start(conf)
    player_mgr:init()
    login_mgr:init()
    msg_handler.init()

    sock_mgr:register_socket_close_callback(function (fd)
        local player = player_mgr:get_by_fd(fd)
        assert(player)

        skynet.send("base_app_mgr", "lua", "bind_account_2_baseapp", player.account, nil)
        skynet.send("room_mgr", "lua", "on_user_offline", player.account)
        player_mgr:remove(player)
        print("remove player -- ", player.account)
    end)
end

function CMD.update_golds(account, golds)
    local player = player_mgr:get_by_account(account)
    if player then
        player:update_golds(golds)
    else
        db:update_player(account, {golds = golds})
    end
end

function CMD.get_clients()
    return sock_mgr:get_clients()
end

function CMD.sendto_client(account, proto_name, msg)
    local obj = player_mgr:get_by_account(account)
    if not obj then
        return
    end

    obj:sendto_client(proto_name, msg)
end

function CMD.bind_account_2_game(account, game_info)
    player_mgr:bind_account_2_game(account, game_info)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, session, cmd, subcmd, ...)
        if cmd == "socket" then
            sock_mgr[subcmd](sock_mgr, ...)
            return
        end

        print(session, cmd, subcmd)
        local f = CMD[cmd]
        assert(f, "can't find dispatch handler cmd = "..tostring(cmd))

        if session > 0 then
            return skynet.ret(skynet.pack(f(subcmd, ...)))
        else
            f(subcmd, ...)
        end
    end)
end)
