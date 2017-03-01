local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'
local util = require 'klinklang.util'

local CreditsScene = BaseScene:extend{
    __tostring = function(self) return "creditsscene" end,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function CreditsScene:update(dt)
end

function CreditsScene:draw()
    love.graphics.push('all')
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(255, 130, 206)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.pop()
end


return CreditsScene
