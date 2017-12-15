local player_mgr = {}
 function player_mgr:init()
    self.player_tbl = {}
    self.fd_2_player = {}
    self.account_2_game = {}
end

function player_mgr:get_by_account(account)
    return self.player_tbl[account]
end

function player_mgr:get_by_fd(fd)
    return self.fd_2_player[fd]
end

function player_mgr:add(obj)
    self.player_tbl[obj.account] = obj
    self.fd_2_player[obj.fd] = obj
end

function player_mgr:remove(obj)
    self.player_tbl[obj.account] = nil
    self.fd_2_player[obj.fd] = nil 
end

function player_mgr:bind_account_2_game(account, game_info)
    self.account_2_game[account] = game_info
end

function player_mgr:get_game_info(account)
    return self.account_2_game[account]
end

return player_mgr

