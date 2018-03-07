local skynet = require "skynet"

local function main()
    skynet.newservice("debug_console", 8081)

    -- login service
    local login = skynet.newservice("login")
    skynet.call(login, "lua", "start", {
        port = 16800,
        maxclient = 1000,
        nodelay = true,
    })

    -- base_app_mgr
    skynet.uniqueservice("base_app_mgr")
    skynet.call("base_app_mgr", "lua", "start")

    -- game_mgr
    skynet.uniqueservice("game_mgr")
    skynet.call("game_mgr", "lua", "start")

    -- room_mgr
    skynet.uniqueservice("room_mgr")

    skynet.exit()
end

skynet.start(main)
