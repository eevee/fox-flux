local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_wire = require 'klinklang.actors.wire'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'

-- Particle-ish effect spawned by destroyed spikes
local DustCloud = actors_base.Actor:extend{
    name = 'dust cloud',
    sprite_name = 'dust cloud',
    z = 9999,

    velocity = Vector(0, -64),
}

function DustCloud:update(dt)
    self.pos = self.pos + self.velocity * dt
    DustCloud.__super.update(self, dt)
end

function DustCloud:on_enter()
    DustCloud.__super.on_enter(self)

    self.sprite:set_pose('default', function()
        worldscene:remove_actor(self)
    end)
end


-- A rubber player can walk through spikes, but if they land atop them, they
-- get poked and stuck.
-- A slime player is unimpeded regardless.
-- A glass player can walk on top of them.
-- A stone player destroys them.
local SpikesUp = actors_base.Actor:extend{
    name = 'spikes up',
    sprite_name = 'spikes up',
    z = 999,  -- just below player; player may redraw us if necessary

    is_broken = false,
}

function SpikesUp:blocks(actor, collision)
    if self.is_broken then
        return false
    end

    if actor.is_player and actor.form == 'glass' and collision.touchtype >= 0 and actors_base.any_normal_faces(collision, Vector(0, -1)) then
        return true
    end
    if actor.is_player and actor.form == 'stone' then
        return true
    end
    return SpikesUp.__super.blocks(self, actor, collision)
end

function SpikesUp:on_collide(actor, movement, collision)
    if self.is_broken then
        return
    end
    if actor.is_player and collision.touchtype > 0 then
        if actor.form == 'stone' then
            if actors_base.any_normal_faces(collision, Vector(0, -1)) then
                self.is_broken = true
                self.sprite:set_pose('broken')
                local x0, y0, x1, y1 = self.shape:bbox()
                for relx = 0, 1, 0.5 do
                    local where = Vector(
                        x0 + (x1 - x0) * relx,
                        y0 + math.random() * (y1 - y0))
                    worldscene:add_actor(DustCloud(where))
                end
            end
        else
            actor:poke(self, collision)
        end
    end
end


-- Blows objects upwards.
-- FIXME not very well at the moment though
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
            local vely = -2048 * (1 - frac * 0.75) * dt / actor.mass
            if actor.velocity.y > vely then
                actor:push(Vector(0, vely))
            end
        end
    end
    worldscene.collider:slide(shape, Vector(), callback)
end


-- Turns on fans
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



local Platform = actors_base.MobileActor:extend{
    name = 'platform',
    sprite_name = 'platform',

    gravity_multiplier = 0,
    can_carry = true,
    is_blockable = false,
    mass = 1000,

    platform_direction = 1,
    platform_slowdown_distance = 32,
}

function Platform:init(pos, props)
    Platform.__super.init(self, pos)

    if props then
        if props['platform track'] then
            -- FIXME would like a nicer way of doing this.  also i observe that
            -- not only platforms necessarily follow tracks...  maybe this
            -- should be generic (component) behavior
            self.platform_points = worldscene.map.named_tracks[props['platform track']]
            self.platform_point = 1
        end
        self.platform_speed = props['platform speed'] or 64
    end
end

function Platform:on_enter()
    Platform.__super.on_enter(self)
    self:move_to(self.platform_points[1]:clone())
end

-- FIXME a horizontal platform in particular looks pretty janky but i'm not
-- totally sure who to blame.  it sometimes jitters relative to the player,
-- too, which is aaaawful.  nudge() does goal rounding, so i'm suspicious of
-- that, but lowering it from 1/8 to 1/32 didn't seem to help
function Platform:update(dt)
    local pt0, pt1
    if self.platform_direction > 0 then
        pt0 = self.platform_point
        pt1 = self.platform_point + 1
    elseif self.platform_direction < 0 then
        pt0 = self.platform_point
        pt1 = self.platform_point - 1
    else
        return
    end

    local goal_is_endpoint = (pt1 == 1 or pt1 == #self.platform_points)
    local departing_endpoint = (pt0 == 1 or pt0 == #self.platform_points)
    local goal = self.platform_points[pt1]
    local delta = goal - self.pos
    local dist = delta:len()
    local max_dist = self.platform_speed * dt

    if max_dist < dist then
        self.velocity = delta * (self.platform_speed / dist)

        if goal_is_endpoint or departing_endpoint then
            local dist_from_end
            if departing_endpoint then
                local dist0 = (self.platform_points[pt0] - self.pos):len()
                if goal_is_endpoint then
                    dist_from_end = math.min(dist, dist0)
                else
                    dist_from_end = dist0
                end
            else
                dist_from_end = dist
            end
            if dist_from_end < self.platform_slowdown_distance then
                self.velocity = self.velocity * (dist_from_end / self.platform_slowdown_distance * 0.75 + 0.25)
            end
        end
    else
        if dt < 1e-8 or dist < 1e-8 then
            self.velocity = Vector()
        else
            self.velocity = delta * (max_dist / dt / dist)
        end

        self.platform_point = pt1
        if goal_is_endpoint then
            local new_direction = -self.platform_direction
            self.platform_direction = 0
            worldscene.tick:delay(function()
                self.platform_direction = new_direction
            end, 1)
        end
    end

    Platform.__super.update(self, dt)
end


local Crate = actors_base.MobileActor:extend{
    name = 'crate',
    sprite_name = 'crate',
    z = -1,

    is_portable = true,
    can_carry = true,
    is_pushable = true,
    can_push = true,
    mass = 4,
}


-- Particle spawned by a destroyed boulder
local RockChunk = actors_base.MobileActor:extend{
    name = 'rock chunk',
    sprite_name = 'rock chunk',
    z = 9999,
}

function RockChunk:blocks()
    return false
end

function RockChunk:on_collide_with()
    return true
end

function RockChunk:on_enter()
    RockChunk.__super.on_enter(self)

    worldscene.tick:delay(function()
        worldscene:remove_actor(self)
    end, 1)
end


-- Solid block that can be destroyed by a large weight landing on it
local Boulder = actors_base.Actor:extend{
    name = 'boulder',
    sprite_name = 'boulder',

    hardness = 2,
    health = 3,
}

function Boulder:blocks()
    return true
end

function Boulder:on_collide(actor, movement, collision)
    if actor.is_player and actor.form == 'stone' and
        collision.touchtype > 0 and
        collision.movement.y > 0 and
        -- Must be moving down
        actors_base.any_normal_faces(collision, Vector(0, -1))
    then
        self.health = self.health - 1

        if self.health == 0 then
            for dx = -1, 1, 2 do
                for dy = -1, 1, 2 do
                    local chunk = RockChunk(self.pos + Vector(dx * 12, dy * 12 - 16))
                    chunk:push(Vector(dx * 32, 16 * (dy - 3)))
                    worldscene:add_actor(chunk)
                end
            end
            worldscene:remove_actor(self)
        elseif self.health == 1 then
            self.sprite:set_pose('very cracked')
        elseif self.health == 2 then
            self.sprite:set_pose('cracked')
        elseif self.health == 3 then
            self.sprite:set_pose('pristine')
        end
    end
end


-- A pushable object that softens falls
local Cushion = actors_base.MobileActor:extend{
    name = 'cushion',
    sprite_name = 'cushion',

    is_portable = true,
    can_carry = true,
    is_pushable = true,
    can_push = true,
    mass = 2,

    hardness = -6,
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


local SewerGrate = actors_base.Actor:extend{
    name = 'sewer grate',
    sprite_name = 'sewer grate',
}

function SewerGrate:blocks(actor)
    if actor.is_player and actor.form == 'slime' then
        return false
    end

    return true
end


local ChainLinkFence = actors_base.Actor:extend{
    name = 'chain-link fence',
    sprite_name = 'chain-link fence',
    z = 9999,
}

function ChainLinkFence:blocks(actor)
    if actor.is_player and actor.form == 'slime' then
        return false
    end

    return true
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


local ForceFloor = ForceField:extend{
    name = 'force floor',
    sprite_name = 'force floor',
}


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


local ConveyorBelt = actors_base.MobileActor:extend{
    name = 'conveyor belt',
    sprite_name = 'conveyor belt',

    can_carry = true,
    -- FIXME once again, this doesn't actually move; it just has cargo
    is_blockable = false,
    gravity_multiplier = 0,

    conveyance_speed = 64,
}

function ConveyorBelt:update(dt)
    local displacement = Vector(self.conveyance_speed * dt, 0)
    for actor in pairs(self.cargo) do
        actor:nudge(displacement, {[self] = true})
    end
end



return {
    Crate = Crate,
    ForceField = ForceField,
    Panel = Panel,
}
