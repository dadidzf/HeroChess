local MongoLib = require "mongolib"
local utils = require "utils"

local dbconf = {
    host = "127.0.0.1",
    port = 27017,
--    db="mj_server",
--    username="yun",
--    password="yun",
--    authmod="mongodb_cr"
}

local M = {}

function M:init()
    self.mongo = MongoLib.new()
    self.mongo:connect(dbconf)
    self.mongo:use("herochess")
end

function M:load_player(account)
    local obj = self.mongo:find_one("account", {account = account}, {_id = false})
    return obj
end

function M:save_player(obj)
    self.mongo:insert("account", obj)
end

function M:update_player(account, content)
    self.mongo:update("account", {query = {account = account}, update = {["$set"] = content}})
end

return M
