local sock_mgr = require "sock_mgr"
local player = require "player"
local player_mgr = require "player_mgr"
local skynet = require "skynet"
local constants = require "constants"
local cjson = require "cjson"

local webclient

local login_mgr = {}

function login_mgr:init()
    self.m_account_map_token = {}
    sock_mgr:register_callback("login.login_baseapp", handler(self, self.auth))

    webclient = skynet.queryservice("webclient")
end

function login_mgr:generate_account_token(account)
    local timeFlag = os.time()
    local token = tostring(account)..tostring(timeFlag)
    self.m_account_map_token[account] = {token = token, time = timeFlag} 
    return token
end

function login_mgr:update_token_table()
    local account_to_be_removed = {}
    for account, tokenInfo in pairs(self.m_account_map_token) do
        local timeNow = os.time()
        if timeNow - tokenInfo.time > 60 then
            table.insert(account_to_be_removed, account)
        end
    end

    for _, account in ipairs(account_to_be_removed) do
        self.m_account_map_token[account] = nil
    end
end

function login_mgr:auth(fd, msg)
    if msg and msg.account and self.m_account_map_token[msg.account].token == msg.token then
        self.m_account_map_token[msg.account] = nil
        self:update_token_table()
        sock_mgr:auth_fd(fd)
        self:on_player_authed(fd, msg)
    else
        return {errmsg = "wrong token"}
    end
end

function login_mgr:on_player_authed(fd, msg)
    local player = player.create(fd, msg.account)
    local unionid = player:get_unionid()
    if unionid then
        if unionid ~= "tourist" then
            local result, msg = self:update_wechat_playerinfo(player)
            if not result then
                sock_mgr:send(fd, "login.login_baseapp", {errmsg = msg})
                return
            end
        end

        player_mgr:add(player)
        sock_mgr:send(fd, "login.login_baseapp", player:pack())
        skynet.send("base_app_mgr", "lua", "bind_account_2_baseapp", msg.account, skynet.self())
        skynet.send("room_mgr", "lua", "on_user_login", {base_app = skynet.self(), account = player:get_account()})
    else
        sock_mgr:send(fd, "login.login_baseapp", {errmsg = "failed to load player"})
    end
end

function login_mgr:update_wechat_playerinfo(player)
    local result, content = skynet.call(webclient, "lua", "request", 
        constants.WECHAT_GET_USER_INFO_URL, 
        {
            access_token = player:get_access_token(), 
            openid = player:get_openid()
        }
    )
    local user_info = cjson.decode(content)
    dump(user_info)
    if user_info.errcode then
        return false, user_info
    else
        player:update_wechat_user_info(user_info.headimgurl, user_info.sex, user_info.nickname)
        return true
    end
end

return login_mgr
