local skynet = require "skynet"
require "skynet.manager"
local base_app_mgr = require "base_app_mgr"

local CMD = {}

function CMD.start()
    -- 初始化base_app_mgr
    base_app_mgr:init()
    base_app_mgr:create_base_apps()
    base_app_mgr:start_base_apps()
end

-- 为玩家分配一个baseapp
function CMD.get_base_app_addr()
    for addr, info in pairs(base_app_mgr:get_base_app_tbl()) do
        local ret = skynet.call(addr, "lua", "get_clients")
        skynet.error(string.format("Current client counts of port %d is %d", info.port, ret.clients))

        if ret.clients < 1000 then
            return {ip = "192.168.18.107", port = info.port, token = "token"}
        end
    end

    return {errmsg = "No more base app to connect !"}
end

function CMD.get_total_clients()
    return base_app_mgr:get_total_clients()
end

function CMD.bind_account_2_baseapp(account, base_app_addr)
    base_app_mgr:bind_account_2_baseapp(account, base_app_addr)
end

function CMD.get_baseapp_by_account(account)
    return base_app_mgr:get_baseapp_by_account(account)
end

local function lua_dispatch(_, session, cmd, ...)
    local f = CMD[cmd]
    assert(f, "base_app_mgr can't dispatch cmd ".. tostring(cmd))

    if session > 0 then
        skynet.ret(skynet.pack(f(...)))
    else
        f(...)
    end
end

local function init()
    skynet.register("base_app_mgr")
    skynet.dispatch("lua", lua_dispatch)
    skynet.error("base_app_mgr booted...")
end

skynet.start(init)
