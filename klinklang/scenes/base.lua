--[[
All this does is rename Gamestate's init hook to scene_init, so it doesn't
conflict with Object.init.
]]
local Object = require 'klinklang.object'

local BaseScene = Object:extend{
    scene_init = function() end,
}

function BaseScene:init()
    self.init = self.scene_init
end

return BaseScene
