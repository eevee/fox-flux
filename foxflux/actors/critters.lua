local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Player = require 'klinklang.actors.player'
local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


-- FIXME don't...  don't inherit player
local Slime = Player:extend{
    name = 'slime',
    sprite_name = 'slime',
}

function Slime:update(dt)
    if love.math.random() < 0.2 * dt then
        self:decide_walk(love.math.random(3) - 2)
    end

    Slime.__super.update(self, dt)
end


return {
    Slime = Slime,
}
