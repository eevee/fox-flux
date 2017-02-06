local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local Slime = actors_base.SentientActor:extend{
    name = 'slime',
    sprite_name = 'slime',

    max_speed = 128,
    xaccel = 600,
    -- FIXME gravity is hardcoded here
    jumpvel = math.sqrt(2 * 675 * 16),
}

function Slime:update(dt)
    local player_dist = worldscene.player.pos - self.pos
    if math.abs(player_dist.x) < 32 then
        if player_dist.x < 0 then
            self:decide_walk(-1)
        else
            self:decide_walk(1)
        end
        self:decide_jump()
    elseif love.math.random() < 0.2 * dt then
        self:decide_walk(love.math.random(3) - 2)
    end

    Slime.__super.update(self, dt)
end


return {
    Slime = Slime,
}
