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
    jumpvel = actors_base.get_jump_velocity(12),

    jump_sound = 'assets/sounds/jump-slime.ogg',

    player_target_offset = Vector(0, -12),
}

function Slime:blocks()
    return false
end

function Slime:on_collide_with(actor, ...)
    if actor and actor.is_player then
        return true
    end
    return Slime.__super.on_collide_with(self, actor, ...)
end

function Slime:update(dt)
    local player = worldscene.player
    local player_delta = (player.pos + self.player_target_offset) - self.pos
    -- TODO oh it would be fascinating if you could absorb more slime that you encountered
    if player:is_transformable() and
        math.abs(player_delta.x) < 96 and
        -40 < player_delta.y and player_delta.y < 8
    then
        if self.move_event then
            self.move_event:stop()
            self.move_event = nil
        end

        -- FIXME so the problem with this is that it's entirely possible to
        -- overshoot if we're moving too quickly...  we would need instead to
        -- check that our movement passed within x units of the player?
        if math.max(math.abs(player_delta.x), math.abs(player_delta.y)) < 4 then
            -- Gotcha!
            worldscene:remove_actor(self)
            player:play_transform_cutscene('slime', self.velocity.x > 0, 'lexy: slime tf')
            return
        end

        local launch_speed = player_delta.x / 0.25
        if self.on_ground and player_delta.y < 0 then
            -- If the player is close enough, launch ourselves at them
            self.velocity.x = launch_speed
            self.jumpvel = actors_base.get_jump_velocity(-player_delta.y)
            self:decide_jump()
        elseif math.abs(self.velocity.x) < math.abs(launch_speed) then
            -- If we're already in the air, try to move in their direction
            self:decide_walk(player_delta.x < 0 and -1 or 1)
        end
    elseif self.decision_walk == 0 then
        -- Otherwise, shuffle around a bit
        -- TODO would be nice to detect hanging over a ledge and not fall off of it
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


-- Inflicts a little fire damage to the player's toes
local Campfire = actors_base.Actor:extend{
    name = 'campfire',
    sprite_name = 'campfire',
    z = 2000,
}

function Campfire:on_enter()
    self:schedule_particle()
end

function Campfire:on_leave()
    if self.particle_event then
        self.particle_event:stop()
        self.particle_event = nil
    end
end

function Campfire:schedule_particle()
    self.particle_event = worldscene.tick:delay(function()
        local pos = Vector(
            self.pos.x + love.math.random(-8, 8),
            self.pos.y + love.math.random(-8, 0))
        local color
        if love.math.random() < 0.5 then
            color = {255, 187, 49}
        else
            color = {246, 143, 55}
        end
        worldscene:add_actor(actors_misc.Particle(
            pos, Vector(0, love.math.random(-160, -64)), Vector.zero, color, love.math.random(1, 3)))
        self:schedule_particle()
    end, love.math.random(0.125, 0.75))
end

function Campfire:on_collide(actor)
    if actor.is_player then
        actor:toast()
    end
end


-- Fluffy rainbow bat that feeds on color, and takes a bit too much from you
local Draclear = actors_base.MobileActor:extend{
    name = 'draclear',
    sprite_name = 'draclear: clear',

    gravity_multiplier = 0,

    pursuit_speed = 128,
    state = 'idle',
    is_sated = false,
    perch_pos = nil,
    player_target_offset = Vector(-6, -44),
}

function Draclear:blocks()
    return false
end

function Draclear:on_collide_with(actor, collision, ...)
    if actor and actor.is_player then
        return true
    end

    local passable = Draclear.__super.on_collide_with(self, actor, collision, ...)

    -- If we hit something while trying to catch the player, give up this time
    if collision.touchtype > 0 and not passable then
        if self.state == 'pursuing' then
            self.state = 'returning'
        end
    end

    return passable
end

function Draclear:update(dt)
    -- FIXME become unsated, eventually
    -- FIXME can get stuck when returning; need another state that just rises
    -- and stops at the first perch
    -- FIXME i suppose it's possible that the perched object moves?
    if self.state == 'idle' then
        self.perch_pos = self.pos
        if worldscene.player:is_transformable() then
            local player_delta = (worldscene.player.pos + self.player_target_offset) - self.pos
            local max_dist = math.max(math.abs(player_delta.x), math.abs(player_delta.y))
            if max_dist < 128 then
                self.state = 'pursuing'
            end
        end
    elseif self.state == 'pursuing' then
        local player = worldscene.player
        if player:is_transformable() then
            local player_delta = (player.pos + self.player_target_offset) - self.pos
            local max_dist = math.max(math.abs(player_delta.x), math.abs(player_delta.y))
            if max_dist > 128 then
                -- Give up if the player is too far away
                self.state = 'returning'
            elseif max_dist < 4 then
                -- Gotcha!
                self.state = 'returning'
                worldscene:remove_actor(self)
                player:play_transform_cutscene('glass', player_delta.x < 0, 'lexy: glass tf', function()
                    -- Player may have moved in the meantime!
                    self.pos = player.pos + self.player_target_offset
                    self:set_sprite('draclear')
                    self.is_sated = true
                    worldscene:add_actor(self)
                end)
                return
            else
                self.velocity = self.pursuit_speed * player_delta:normalized()
                self.sprite:set_pose('fly')
                self.sprite:set_facing_right(self.velocity.x > 0)
            end
        else
            self.state = 'returning'
        end
    elseif self.state == 'returning' then
        local perch_delta = self.perch_pos - self.pos
        local perch_dist = perch_delta:len()

        if perch_dist > 2 then
            self.velocity = perch_delta * math.min(1 / dt, self.pursuit_speed / perch_dist)
            self.sprite:set_pose('fly')
            self.sprite:set_facing_right(self.velocity.x > 0)
        else
            self.pos = self.perch_pos:clone()
            self.velocity = Vector()
            self.sprite:set_pose('perch')
            self.state = 'waiting'
            if self.is_sated then
                -- Stuffed!  Wait for a while before it wears off
                worldscene.tick:delay(function()
                    self.sprite:set_pose('fade', function()
                        self.is_sated = false
                        self.state = 'idle'
                        self:set_sprite('draclear: clear')
                    end)
                end, util.random_float(8, 16))
            else
                -- Still hungry; just wait a bit before pursuing again
                worldscene.tick:delay(function()
                    self.state = 'idle'
                end, util.random_float(3, 7))
            end
        end
    end

    Draclear.__super.update(self, dt)
end


-- Turns the player to stone on touch
local ReverseCockatrice = actors_base.SentientActor:extend{
    name = 'reverse cockatrice',
    sprite_name = 'reverse cockatrice',

    max_speed = 64,
}

function ReverseCockatrice:blocks()
    return false
end

function ReverseCockatrice:on_collide(actor)
    if actor.is_player and actor:is_transformable() then
        actor:transform('stone')
    end
end

function ReverseCockatrice:update(dt)
    -- FIXME would be nice to not walk off ledges
    if not self.move_event then
        self.move_event = worldscene.tick:delay(function()
            -- FIXME don't move in directions we already know we're blocked
            self:decide_walk(love.math.random(3) - 2)
        end, love.math.random(0.5, 2))
        self.move_event:after(function()
            self:decide_walk(0)
            self.move_event = nil
        end, love.math.random(0.5, 2.0))
    end

    ReverseCockatrice.__super.update(self, dt)
end




local Gecko = actors_base.SentientActor:extend{
    name = 'gecko',
    sprite_name = 'gecko',

    max_speed = 256,
}

function Gecko:blocks()
    return false
end

function Gecko:on_collide(actor)
    if actor.is_player and not actor.is_locked and actor.form == 'stone' then
        actor:transform('rubber')
    end
end

function Gecko:update(dt)
    -- FIXME would be nice to not walk off ledges
    if not self.move_event then
        self.move_event = worldscene.tick:delay(function()
            -- FIXME don't move in directions we already know we're blocked
            self:decide_walk(love.math.random(3) - 2)
        end, love.math.random(0.5, 2))
        self.move_event:after(function()
            self:decide_walk(0)
            self.move_event = nil
        end, love.math.random(0.5, 2.0))
    end

    Gecko.__super.update(self, dt)
end



return {
    Slime = Slime,
    Draclear = Draclear,
}
