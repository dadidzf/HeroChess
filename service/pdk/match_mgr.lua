-- 房间管理器
local match_mgr = {}

function match_mgr:init()
    self.tbl = {}
end

function match_mgr:get(id)
    return self.tbl[id]
end

function match_mgr:add(obj)
    self.tbl[obj.id] = obj
end

function match_mgr:remove(obj)
    self.tbl[obj.id] = nil
end

function match_mgr:remove_by_id(id)
    self.tbl[id] = nil
end

return match_mgr
