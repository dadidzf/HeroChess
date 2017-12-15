local skynet = require "skynet"
local socket = require "skynet.socket"
local utils = require "utils"
local packer = require "packer"
local msg_define = require "msg_define"

local sock_mgr = {
    dispatch_tbl = {},
    authed_fd = {},
    clients = 0
}

function sock_mgr:start(conf)
    self.gate = skynet.newservice("gate")
    skynet.call(self.gate, "lua", "open", conf)

    skynet.error("login service listen on port ", conf.port)
end

function sock_mgr:inc_clients()
    self.clients = self.clients + 1
end

function sock_mgr:dec_clients()
    if self.clients > 0 then
        self.clients = self.clients - 1
    end
end

function sock_mgr:get_clients()
    return self.clients
end

function sock_mgr:auth_fd(fd)
    self.authed_fd[fd] = true
end

-------------------处理socket消息开始--------------------
function sock_mgr:open(fd, addr)
    skynet.error("New client from : " .. addr)
    skynet.call(self.gate, "lua", "accept", fd)

    self:inc_clients()
end

function sock_mgr:close(fd)
    self:close_conn(fd)
    skynet.error("socket close "..fd)
end

function sock_mgr:error(fd, msg)
    self:close_conn(fd)
    skynet.error("socket error "..fd.." msg "..msg)
end

function sock_mgr:warning(fd, size)
    skynet.error(string.format("%dK bytes havn't send out in fd=%d", size, fd))
end

function sock_mgr:data(fd, msg)
    skynet.error(string.format("recv socket data fd = %d, len = %d ", fd, #msg))

    local proto_id, params = string.unpack(">Hs2", msg)
    local proto_name = msg_define.idToName(proto_id)
    skynet.error(string.format("socket msg id:%d name:%s %s", proto_id, proto_name, params))

    if self.authed_fd[fd]  or (proto_name == "login.login_baseapp") then
        self:dispatch(fd, proto_id, proto_name, params)
    else
        skynet.call(self.gate, "lua", "kick", fd)
        skynet.error("msg not authed!")
    end
end

function sock_mgr:close_conn(fd)
    if self.authed_fd[fd] and self.socket_close_callback then
        self.socket_close_callback(fd)
    end

    self.authed_fd[fd] = nil
    self:dec_clients()
end

function sock_mgr:register_socket_close_callback(callback)
    self.socket_close_callback = callback
end

-------------------处理socket消息结束--------------------

-------------------网络消息回调函数开始------------------
function sock_mgr:register_callback(name, func)
    self.dispatch_tbl[name] = func
end

function sock_mgr:dispatch(fd, proto_id, proto_name, params)
    params = utils.str_2_table(params)
    local func = self.dispatch_tbl[proto_name]
    if not func then
        skynet.error("协议编号"..proto_id)
        skynet.error("can't find socket callback "..proto_name)
        return
    end

    local ret = func(fd, params)
    if ret then
        skynet.error("ret msg:"..utils.table_2_str(ret))
        socket.write(fd, packer.pack(proto_id, ret))
    end
end

function sock_mgr:send(fd, proto_name, msg)
    local proto_id = msg_define.nameToId(proto_name)
    local str = utils.table_2_str(msg)
    skynet.error("send msg:"..proto_name)
    socket.write(fd, packer.pack(proto_id, msg))
end
-------------------网络消息回调函数结束------------------

return sock_mgr
