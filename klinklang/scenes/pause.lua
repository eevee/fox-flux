local Gamestate = require 'vendor.hump.gamestate'

local BaseScene = require 'klinklang.scenes.base'

local PauseScene = BaseScene:extend{
    __tostring = function(self) return "pausescene" end,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function PauseScene:enter(previous_scene)
    self.wrapped = previous_scene
end

function PauseScene:update(dt)
end

function PauseScene:draw()
    self.wrapped:draw()

    --[[
    local w, h = love.graphics.getDimensions()
    love.graphics.push('all')
    love.graphics.setColor(0, 0, 0, 128)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf('* p a u s e d *', math.floor(w / 2), 
    love.graphics.pop()
    ]]
end

function PauseScene:keypressed(key, scancode, isrepeat)
    if (scancode == 'escape' or scancode == 'pause') and not love.keyboard.isScancodeDown('lctrl', 'rctrl', 'lalt', 'ralt', 'lgui', 'rgui') then
        Gamestate.pop()
    end
end


return PauseScene
