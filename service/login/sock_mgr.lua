local skynet = require "skynet"
local socket = require "skynet.socket"
local utils = require "utils"
local packer = require "packer"
local account_mgr = require "account_mgr"
local msg_define = require "msg_define"
local cjson = require "cjson"
local constants = require "constants"
local webclient

local sock_mgr = {}

function sock_mgr:start(conf)
    self.gate = skynet.newservice("gate")

    skynet.call(self.gate, "lua", "open", conf)

    skynet.error("login service listen on port "..conf.port)

    self:register_callback()

    webclient = skynet.queryservice("webclient")
end

-------------------处理socket消息开始--------------------
function sock_mgr:open(fd, addr)
    skynet.error("New client from : " .. addr)
    skynet.call(self.gate, "lua", "accept", fd)
end

function sock_mgr:close(fd)
    skynet.error("socket close "..fd)
end

function sock_mgr:error(fd, msg)
    skynet.error("socket error "..fd)
end

function sock_mgr:warning(fd, size)
    -- size K bytes havn't send out in fd
    skynet.error("socket warning "..fd)
end

function sock_mgr:data(fd, msg)
    skynet.error(string.format("socket data fd = %d, len = %d ", fd, #msg))
    local proto_id, params = string.unpack(">Hs2", msg)

    skynet.error(string.format("msg id:%d content:%s", proto_id, params))
    params = utils.str_2_table(params)

    local proto_name = msg_define.idToName(proto_id)

    self:dispatch(fd, proto_id, proto_name, params)
end
-------------------处理socket消息结束--------------------

-------------------网络消息回调函数开始------------------
function sock_mgr:register_callback()
    self.dispatch_tbl = {
        ["login.login"] = self.login,
        ["login.register"] = self.register,
        ["login.wechat_login"] = self.wechat_login,
    }
end

function sock_mgr:dispatch(fd, proto_id, proto_name, params)
    local f = self.dispatch_tbl[proto_name]
    if not f then
        skynet.error("can't find socket callback "..proto_id)
        return
    end

    local ret_msg = f(self, fd, params)
    if ret_msg then
        local close_socket = ret_msg.close_socket
        ret_msg.close_socket = nil

        skynet.error("ret msg:"..utils.table_2_str(ret_msg))
        socket.write(fd, packer.pack(proto_id, ret_msg))

        if close_socket then
            skynet.call(self.gate, "lua", "kick", fd)
        end
    end
end

function sock_mgr:login(fd, msg)
    skynet.error(string.format("verfy account:%s passwd:%s ", msg.username, msg.passwd))
    local success, errmsg = account_mgr:verify(msg.username, msg.passwd)
    if not success then
        return {errmsg = errmsg}
    end

    local user = account_mgr:get_by_username(msg.username)
    local ret = skynet.call("base_app_mgr", "lua", "get_base_app_addr", user.account)
    ret.close_socket = true
    ret.account = account 

    return ret
end

function sock_mgr:register(fd, msg)
    local success, info = account_mgr:register(msg.username, msg.passwd)

    if success then
        return {close_socket = false}
    else
        return {errmsg = info}
    end
end

-- wechat 
function sock_mgr:wechat_login(fd, msg)
    local result, content = skynet.call(webclient, "lua", "request", 
            constants.WECHAT_AUTH_URL, 
            {
                appid = constants.APP_ID, 
                code = msg.code, grant_type = "authorization_code", 
                secret = constants.APP_SECRET
            }
        )
    local auth_info = cjson.decode(content)
    dump(auth_info)
    if auth_info.errcode then
        return {errmsg = auth_info}
    else
        local account = account_mgr:wechat_register(auth_info)
        local ret = skynet.call("base_app_mgr", "lua", "get_base_app_addr", account)
        ret.close_socket = true
        ret.account = account

        return ret
    end
end


-------------------网络消息回调函数结束------------------

return sock_mgr
