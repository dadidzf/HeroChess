local skynet = require "skynet"

local base_app_mgr = {}

function base_app_mgr:init()
    self.base_app_tbl = {}
    self.account_2_baseapp = {}
end

-- 创建baseapp
function base_app_mgr:create_base_apps()
    for i = 1, 2 do
        local addr = skynet.newservice("base_app", i)
        local info = {
            addr = addr,
            port = 16800 + i
        }

        self.base_app_tbl[addr] = info
    end
end

function base_app_mgr:start_base_apps()
    for _,v in pairs(self.base_app_tbl) do
        skynet.call(v.addr, "lua", "start", {
            port = v.port,
            maxclient = 1000,
            nodelay = true,
        })
    end
end

function base_app_mgr:get_base_app_info(addr)
    return self.base_app_tbl[addr]
end

function base_app_mgr:get_base_app_tbl()
    return self.base_app_tbl
end

function base_app_mgr:bind_account_2_baseapp(account, base_app_addr)
    self.account_2_baseapp[account] = base_app_addr
end

function base_app_mgr:get_baseapp_by_account(account)
    return self.account_2_baseapp[account]
end

function base_app_mgr:get_total_clients()
    local clients_cnt = 0
    for _, base_app in pairs(self.base_app_tbl) do
        clients_cnt = skynet.call(base_app.addr, "lua", "get_clients") + clients_cnt
    end

    return clients_cnt
end

return base_app_mgr
