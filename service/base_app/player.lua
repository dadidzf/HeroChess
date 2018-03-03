local db = require "db"
local sock_mgr = require "sock_mgr"

local player = {}

player.__index = player

function player.create(...)
    local o = {}
    setmetatable(o, player)

    player.init(o, ...)
    return o
end

function player:init(fd, account, username)
    self.fd = fd
    self.account = account
    self.username = username
    self.status = "load from db"
end

function player:load_from_db()
    local obj = db:load_player(self.account)
    if obj then
        self._db = obj
    else
        self:_create_db()
    end
end

function player:_create_db()
    local obj = {
        account = self.account,
        nick_name = self.username,
        exp = 0,
        golds = 0
    }
    db:save_player(obj)
    self._db = obj
end

function player:pack()
    return {
        account = self.account,
        nick_name = self._db.nick_name,
        exp = self._db.exp,
        golds = self._db.golds
    }
end

function player:get_info()
    return self:pack() 
end

function player:update_golds(golds)
    self._db.golds = golds
    db:update_player(self.account, {golds = golds})
end

function player:update_exp(exp)
    self._db.exp = exp
    db:update_player(self.account, {exp = exp})
end

function player:sendto_client(proto_name, msg)
    sock_mgr:send(self.fd, proto_name, msg)
end

function player:get_account()
    return self.account
end

return player
