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

function player:init(fd, account)
    self.fd = fd
    self.account = account
    self:load_from_db()
end

function player:load_from_db()
    local obj = db:load_player(self.account)
    if obj then
        self._db = obj
    end
end

function player:getDb()
    return self._db
end

function player:pack()
    return {
        account = self.account,
        nick_name = self._db.nickname,
        exp = self._db.exp,
        golds = self._db.golds,
        headimgurl = self._db.headimgurl
    }
end

function player:get_nickname()
    return self._db.username
end

function player:get_unionid()
    return self._db.unionid
end

function player:get_access_token()
    return self._db.access_token
end

function player:get_openid()
    return self._db.openid
end

function player:get_info()
    return self:pack() 
end

function player:update_wechat_user_info(headimgurl, sex, nickname)
    self._db.headimgurl = headimgurl
    self._db.sex = sex
    self._db.nickname = nickname
    db:update_player(self.account, {headimgurl = headimgurl, sex = sex, nickname = nickname})
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
