local skynet = require "skynet"
local MongoLib = require "mongolib"
local utils = require "utils"

local mongo_host = "127.0.0.1"
local mongo_db = "herochess"

local dbconf = {
    host = "127.0.0.1",
    port = 27017,
--    db="game",
--    username="yun",
--    password="yun",
--    authmod="mongodb_cr"
}

local _account_min = 100000
local _account_max = 999999

local account_mgr = {}

function account_mgr:init()
    self.mongo = MongoLib.new()
    self.mongo:connect(dbconf)
    self.mongo:use(mongo_db)
    self.account_tbl = {}

    self:load_all()
end

function account_mgr:gen_account()
    self:recycle_accounts()

    local len = #self.rest_account_tbl
    local index = math.random(1, len)
    local new_account = self.rest_account_tbl[index]
    self.accounts_to_be_registered[new_account] = true
    self.accounts_to_be_registered_count = self.accounts_to_be_registered_count + 1
    self.rest_account_tbl[index] = self.rest_account_tbl[len]
    self.rest_account_tbl[len] = nil

    print("account_mgr:gen_account -- rest ", len)
    return tostring(new_account)
end

function account_mgr:recycle_accounts()
    if self.accounts_to_be_registered_count > 100 then
        for account, _ in pairs(self.accounts_to_be_registered) do
            table.insert(self.rest_account_tbl, account)
        end

        self.accounts_to_be_registered = {}
        self.accounts_to_be_registered_count = 0
    end
end

function account_mgr:load_all()
    self.rest_account_tbl = {}
    local it = self.mongo:find("account", {}, {_id = false})
    if not it then
        return
    end

    while it:hasNext() do
        local obj = it:next()
        self.account_tbl[obj.account] = obj
    end

    for i = _account_min, _account_max do
        -- account should be string, but we use number here to save the memory
        if not self.account_tbl[tostring(i)] then
            table.insert(self.rest_account_tbl, i)
        end
    end

    self.accounts_to_be_registered = {}
    self.accounts_to_be_registered_count = 0
end

function account_mgr:get_by_account(account)
    return self.account_tbl[account]
end

-- 验证账号密码
function account_mgr:verify(account, passwd)
    local info = self.account_tbl[account]
    if not info then
        return false, "account not exist"
    end

    if info.passwd ~= passwd then
        return false, "wrong password"
    end

    return true
end

-- 注册账号
function account_mgr:register(account, passwd)
    if not self:check_register(account, passwd) then
        return false, "format error"
    end

    if self.account_tbl[account] then
        return false, "account exists"
    end

    local num_account = tonumber(account) 
    if self.accounts_to_be_registered[num_account] then
        self.accounts_to_be_registered[num_account] = nil
    else
        return false, "account error"
    end

    local info = {account = account, passwd = passwd}
    self.account_tbl[account] = info
    self.rest_account_tbl[tonumber(account)] = false
    self.mongo:insert("account", info)

    return true, account
end

function account_mgr:check_register(account, passwd)
    local num_account = tonumber(account)
    local num_passwd = tonumber(passwd)

    if type(account) == "string" and type(passwd) == "string" and
        num_account and num_passwd and num_account >= _account_min and 
        num_account <= _account_max and #passwd == 6 then
        return true
    else
        return false
    end
end

return account_mgr
