local skynet = require "skynet"
local player_mgr = require "player_mgr"
local player = require "player"
local db = require "db"

local system = {}

function system.get_user_info(fd, request)
    local player = player_mgr:get_by_account(request.account)
    if not player then
        local player = player.create(fd, request.account)
    end

    if player:getDb() then
        return player:pack()
    else
        return {errmsg = "player not exister !"}
    end
end

return system
