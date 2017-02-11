local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local FloorButton = actors_base.Actor:extend{
    name = 'floor button',
    sprite_name = 'floor button',

    is_pressed = false,
}

function FloorButton:blocks(actor, direction)
    return not self.is_pressed
end

function FloorButton:on_collide(actor, movement, collision)
    if not self.is_pressed and collision.touchtype > 0 then
        for normal in pairs(collision.normals) do
            if normal.y < 0 then
                self.is_pressed = true
                self.sprite:set_pose('pressed')
                break
            end
        end
    end
end



-- TODO to make this work:
-- 1. detect mobile objects that are on top of us
-- 2. constant velocity; ignore collisions, don't truncate velocity
-- 3. when moving, nudge passengers by the same amount
local Platform = actors_base.MobileActor:extend{
    name = 'platform',
    sprite_name = 'platform',

    gravity_multiplier = 0,
    can_carry = true,
    is_portable = false,

    plat_distance = 4 * 32,
    plat_speed = 32,
    plat_forwards = true,
}

function Platform:on_enter()
    Platform.__super.on_enter(self)
    self.pos0 = self.pos:clone()
end

function Platform:update(dt)
    -- FIXME this doesn't prevent, e.g., overshooting.  it also doesn't slow
    -- down nicely at the ends.  probably need a more formal concept of a track
    -- to follow -- maybe even definable within tiled?
    if self.plat_forwards then
        if (self.pos - self.pos0):len2() > self.plat_distance * self.plat_distance then
            self.plat_forwards = false
        end
    else
        if self.pos.x < self.pos0.x then
            self.plat_forwards = true
        end
    end

    if self.plat_forwards then
        self.velocity = Vector(self.plat_speed, 0)
    else
        self.velocity = Vector(-self.plat_speed, 0)
    end

    Platform.__super.update(self, dt)
end


local Crate = actors_base.MobileActor:extend{
    name = 'crate',
    sprite_name = 'crate',

    is_pushable = true,
    can_carry = true,
    mass = 1.5,
}

function Crate:on_collide(actor, direction, collision)
    local hit_side
    for normal in pairs(collision.normals) do
        if normal.x ~= 0 then
            hit_side = normal
            break
        end
    end
    if not hit_side then
        return
    end
end


local ForceField = actors_base.Actor:extend{
    name = 'force field',
    sprite_name = 'force field',

    active = true,
}

function ForceField:blocks(actor)
    if actor.is_player and actor.sprite_name == 'lexy: glass' then
        return false
    else
        return self.active
    end
end

function ForceField:draw()
    if self.active then
        return ForceField.__super.draw(self)
    end
end

function ForceField:on_activate_panel(state)
    self.active = state
end


local Panel = actors_base.Actor:extend{
    name = 'panel',
    sprite_name = 'panel',
    z = -1000,

    is_usable = true,

    state = true,
}

function Panel:on_use(activator)
    local state = not self.state
    for _, actor in ipairs(worldscene.actors) do
        if actor.on_activate_panel then
            actor:on_activate_panel(state)
        end
    end
end

function Panel:on_activate_panel(state)
    self.state = state
    if state then
        self.sprite:set_pose('on')
    else
        self.sprite:set_pose('off')
    end
end


return {
    Crate = Crate,
    ForceField = ForceField,
    Panel = Panel,
}
