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
    self.user_tbl = {}
    self.rest_account_tbl = {}

    self:load_all()
end

function account_mgr:load_all()
    local it = self.mongo:find("account", {}, {_id = false})
    if not it then
        return
    end

    local already_used_account_tbl = {}
    while it:hasNext() do
        local obj = it:next()
        self.user_tbl[obj.username] = obj
        already_used_account_tbl[obj.account] = true
    end

    for i = _account_min, _account_max do
        -- user id should be string, but we use number here to save the memory
        if not already_used_account_tbl[i] then
            table.insert(self.rest_account_tbl, i)
        end
    end
end

function account_mgr:gen_new_account()
    local len = #self.rest_account_tbl
    local index = math.random(1, len)
    local new_id = self.rest_account_tbl[index]

    self.rest_account_tbl[index] = self.rest_account_tbl[len]
    self.rest_account_tbl[len] = nil

    return new_id
end

function account_mgr:get_by_username(username)
    return self.user_tbl[username]
end

-- 验证账号密码
function account_mgr:verify(username, passwd)
    if type(username) ~= "string" then
        return false, "username should be string"
    end

    local info = self.user_tbl[username]
    if not info then
        return false, "account not exist"
    end

    if info.passwd ~= passwd then
        return false, "wrong password"
    end

    return true
end

-- 注册账号
function account_mgr:register(username, passwd)
    if not self:check_register_fmt(username, passwd) then
        return false, "format error"
    end

    if self.user_tbl[username] then
        return false, "username exists"
    end

    local user_info = {username = username, passwd = passwd, account = self:gen_new_account()}
    self.user_tbl[username] = user_info 
    self.mongo:insert("account", user_info)

    return true, account
end

function account_mgr:check_register_fmt(username, passwd)
    local num_passwd = tonumber(passwd)

    if type(username) == "string" and type(passwd) == "string" and
        string.len(username) >= 6 and string.len(username) <= 8 and string.len(passwd) == 6 and
        (not string.match(passwd, "%D")) and (not string.match(username, "%W")) then
        return true
    else
        return false
    end
end

return account_mgr
