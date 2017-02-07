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
    jumpvel = math.sqrt(2 * 675 * 12),
}

function Slime:update(dt)
    local player_dist = worldscene.player.pos - self.pos
    if math.abs(player_dist.x) < 64 and math.abs(player_dist.y) < 16 then
        -- If the player is close enough, launch ourselves at them
        self.velocity.x = player_dist.x / 0.25
        self:decide_jump()
        if self.move_event then
            self.move_event:stop()
            self.move_event = nil
        end
    elseif self.decision_walk == 0 then
        -- Otherwise, shuffle around a bit
        if love.math.random() < dt * 0.5 then
            self:decide_walk(love.math.random(3) - 2)
            self.move_event = worldscene.tick:delay(function()
                self:decide_walk(0)
                self.move_event = nil
            end, love.math.random(0.5, 1.5))
        end
    end

    Slime.__super.update(self, dt)
end


-- Fluffy rainbow bat that feeds on color, and takes a bit too much from you
local Draclear = actors_base.MobileActor:extend{
    name = 'draclear',
    sprite_name = 'draclear: clear',

    gravity_multiplier = 0,

    is_pursuing = false,
    pursuit_speed = 128,
}

function Draclear:update(dt)
    -- FIXME currently we just float gently upwards when sated
    -- FIXME become unsated, eventually
    -- FIXME probably just stop and reset as soon as we hit something above us?
    if self.state == 'sated' then
        -- Do nothing; just fly away
        -- FIXME err, also disable collision checking, i suppose
    else
        local player_dist = (worldscene.player.pos + Vector(-6, -37)) - self.pos
        if math.abs(player_dist.x) < 128 and math.abs(player_dist.y) < 128 then
            self.is_pursuing = true
        else
            self.is_pursuing = false
        end

        if self.is_pursuing then
            self.velocity = self.pursuit_speed * player_dist:normalized()
            self.sprite:set_pose('fly')
            self.sprite:set_facing_right(self.velocity.x > 0)
        -- TODO else...
        end
    end

    Draclear.__super.update(self, dt)
end

function Draclear:sate()
    self.state = 'sated'
    self:set_sprite('draclear')
    self.velocity = Vector(120, -60)
end


return {
    Slime = Slime,
    Draclear = Draclear,
}
