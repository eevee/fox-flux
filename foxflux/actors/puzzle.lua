local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_wire = require 'klinklang.actors.wire'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


-- A rubber player can walk through spikes, but if they land atop them, they
-- get poked and stuck.
-- A slime player is unimpeded regardless.
-- A glass player can walk on top of them.
local SpikesUp = actors_base.Actor:extend{
    name = 'spikes up',
    sprite_name = 'spikes up',
    z = 999,  -- just below player; player may redraw us if necessary
}

function SpikesUp:blocks(actor, collision)
    if actor.is_player and actor.form == 'glass' and collision.touchtype >= 0 and actors_base.any_normal_faces(collision, Vector(0, -1)) then
        return true
    end
    return SpikesUp.__super.blocks(self, actor, collision)
end

function SpikesUp:on_collide(actor, movement, collision)
    if actor.is_player and collision.touchtype > 0 then
        actor:poke(self, collision)
    end
end


local Fan = actors_base.Actor:extend{
    name = 'fan',
    sprite_name = 'fan',

    is_active = false,
}

function Fan:update(dt)
    Fan.__super.update(self, dt)

    if not self.is_active then
        return
    end

    local height = 128
    local x0, y0, x1, y1 = self.shape:bbox()
    local shape = whammo_shapes.Box(x0, y0 - height, x1 - x0, height)
    local callback = function(collision)
        local actor = worldscene.collider:get_owner(collision.shape)
        if actor == self then
            return
        end
        if type(actor) == 'table' and actor.isa and actor:isa(actors_base.MobileActor) then
            local ax0, ay0, ax1, ay1 = collision.shape:bbox()
            if ay1 > y0 then
                return
            end

            local frac = (y0 - ay1) / height
            -- FIXME i am having a hell of a time making this strong enough
            -- that it actually lifts you up (even when falling), but not so
            -- strong that it launches you into the stratosphere
            actor:push(Vector(0, -2048) * ((1 - frac * frac * 0.0) * dt))
        end
    end
    worldscene.collider:slide(shape, Vector(), callback)
end


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

                for _, other in ipairs(worldscene.actors) do
                    if other:isa(Fan) then
                        other.is_active = true
                        other.sprite:set_pose('on')
                    end
                end
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
    is_blockable = false,
    mass = 1000,

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
        if self.pos.y > self.pos0.y then
            self.plat_forwards = true
        end
    end

    if self.plat_forwards then
        self.velocity = Vector(0, -self.plat_speed)
    else
        self.velocity = Vector(0, self.plat_speed)
    end

    Platform.__super.update(self, dt)
end


local Crate = actors_base.MobileActor:extend{
    name = 'crate',
    sprite_name = 'crate',

    is_portable = true,
    can_carry = true,
    is_pushable = true,
    can_push = true,
    mass = 4,
}


-- A pushable object that softens falls
local Cushion = actors_base.MobileActor:extend{
    name = 'cushion',
    sprite_name = 'cushion',

    is_portable = true,
    can_carry = true,
    is_pushable = true,
    can_push = true,
    mass = 2,

    hardness = -3,
}

function Cushion:update(dt)
    Cushion.__super.update(self, dt)

    local any_cargo
    for actor in pairs(self.cargo) do
        any_cargo = true
        break
    end
    if any_cargo then
        self.sprite:set_pose('occupied')
    else
        self.sprite:set_pose('flat')
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


-- FIXME this is a stupid hack because Wirable is an Actor, so i can't make a
-- MobileActor also be wirable.  i ALSO need a sprite for it because i can't
-- make a BareActor be wirable!!
local PressurePlateEmitter = actors_wire.Wirable:extend{
    sprite_name = 'wire ns',
    nodes = {Vector(0, 16)},
    can_receive = false,
}

function PressurePlateEmitter:draw()
end

-- FIXME it seems perhaps odd to call this a "mobile" actor when it doesn't
-- actually move?  i just want the cargo support.  which i could do just as
-- well by adding my own cargo thing?
local PressurePlate = actors_base.MobileActor:extend{
    name = 'pressure plate',
    sprite_name = 'pressure plate',

    can_carry = true,
    gravity_multiplier = 0,

    is_broken = false,
}

function PressurePlate:on_enter()
    PressurePlate.__super.on_enter(self)

    local emitter = PressurePlateEmitter(self.pos)
    self.ptrs.emitter = emitter
    worldscene:add_actor(emitter)
end

function PressurePlate:on_leave()
    if self.ptrs.emitter then
        worldscene:remove_actor(self.ptrs.emitter)
        self.ptrs.emitter = false
    end
end

function PressurePlate:update(dt)
    self.velocity = Vector()
    PressurePlate.__super.update(self, dt)

    if not self.is_broken then
        local total_mass = self:_sum_mass(self, {})
        if total_mass >= 10 then
            self.is_broken = true
            self.sprite:set_pose('broken')
            self.ptrs.emitter.powered = 1
            self.ptrs.emitter:_emit_pulse(true)
        elseif total_mass >= 5 then
            self.sprite:set_pose('active')
            -- FIXME well this is not the friendliest api
            self.ptrs.emitter.powered = 1
            self.ptrs.emitter:_emit_pulse(true)
        else
            self.sprite:set_pose('inactive')
            self.ptrs.emitter.powered = 0
            self.ptrs.emitter:_emit_pulse(false)
        end
    end
end

-- Sum up the total mass of all of the base object's cargo, excluding any that
-- have already been seen
function PressurePlate:_sum_mass(base, seen)
    if not base.cargo then
        return 0
    end

    local total_mass = 0
    for actor in pairs(base.cargo) do
        seen[actor] = true
        total_mass = total_mass + actor.mass + self:_sum_mass(actor, seen)
    end
    return total_mass
end




return {
    Crate = Crate,
    ForceField = ForceField,
    Panel = Panel,
}
