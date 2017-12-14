local game_list = require "game_list"
local id_mgr = {}

function id_mgr:init()
    math.randomseed(os.time())
    self.tbl =  {}
    for i = 1, 999999 do
        self.tbl[i] = i
    end
end

function id_mgr:gen_id(game_id)
    local len = #self.tbl 
    local index = math.random(1, len)
    local ret_id = self.tbl[index]
    self.tbl[index] = self.tbl[len]
    self.tbl[len] = nil

    return ret_id
end

function id_mgr:id_recover(room_id)
    table.insert(self.tbl, room_id)
end

return id_mgr
