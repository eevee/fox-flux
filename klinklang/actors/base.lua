local Vector = require 'vendor.hump.vector'

local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'

-- ========================================================================== --
-- BareActor
-- An extremely barebones actor, implementing only the bare minimum of the
-- interface.  Most actors probably want to inherit from Actor, which supports
-- drawing from a sprite.  Code operating on arbitrary actors should only use
-- the properties and methods defined here.
local BareActor = Object:extend{
    pos = nil,

    -- If true, the player can "use" this object, calling on_use(activator)
    is_usable = false,

    -- Used for debug printing; should only be used for abstract types
    __name = 'BareActor',

    -- Table of all known actor types, indexed by name
    name = nil,
    _ALL_ACTOR_TYPES = {},
}

function BareActor:extend(...)
    local class = BareActor.__super.extend(self, ...)
    if class.name ~= nil then
        self._ALL_ACTOR_TYPES[class.name] = class
    end
    return class
end

function BareActor:__tostring()
    return ("<%s %s at %s>"):format(self.__name, self.name, self.pos)
end

function BareActor:get_named_type(name)
    local class = self._ALL_ACTOR_TYPES[name]
    if class == nil then
        error(("No such actor type %s"):format(name))
    end
    return class
end


-- Main update and draw loops
function BareActor:update(dt)
end

function BareActor:draw()
end

-- Called when the actor is added to the world
function BareActor:on_enter()
end

-- Called when the actor is removed from the world
function BareActor:on_leave()
end

-- Called every frame that another actor is touching this one
-- TODO that seems excessive?
-- FIXME that's not true, anyway; this fires on a slide, but NOT if you just
-- sit next to it.  maybe this just shouldn't fire for slides?
function BareActor:on_collide(actor, direction)
end

-- Called when this actor is used (only possible if is_usable is true)
function BareActor:on_use(activator)
end

-- Determines whether this actor blocks another one.  By default, actors are
-- non-blocking, and mobile actors are blocking
function BareActor:blocks(actor, direction)
    return false
end

-- FIXME should probably have health tracking and whatnot
function BareActor:damage(source, amount)
end

-- General API stuff for controlling actors from outside
function BareActor:move_to(position)
    self.pos = position
end


-- ========================================================================== --
-- Actor
-- Base class for an actor: any object in the world with any behavior at all.
-- (The world also contains tiles, but those are purely decorative; they don't
-- have an update call, and they're drawn all at once by the map rather than
-- drawing themselves.)
local Actor = BareActor:extend{
    __name = 'Actor',
    -- TODO consider splitting me into components

    -- Should be provided in the class
    -- TODO are these part of the sprite?
    shape = nil,
    anchor = nil,
    -- Visuals (should maybe be wrapped in another object?)
    sprite_name = nil,
    -- TODO this doesn't even necessarily make sense...?
    facing_left = false,

    -- Indicates this is an object that responds to the use key
    is_usable = false,

    -- Makes an actor immune to gravity and occasionally spawn white particles.
    -- Used for items, as well as the levitation spell
    is_floating = false,

    -- Completely general-purpose timer
    timer = 0,
}

function Actor:init(position)
    self.pos = position
    self.velocity = Vector.zero:clone()

    -- Table of weak references to other actors
    self.ptrs = setmetatable({}, { __mode = 'v' })

    -- TODO arrgh, this global.  sometimes i just need access to the game.
    -- should this be done on enter, maybe?
    -- TODO shouldn't the anchor really be part of the sprite?  hm, but then
    -- how would our bounding box change?
    -- FIXME should show a more useful error if this is missing
    if not game.sprites[self.sprite_name] then
        error(("No such sprite named %s"):format(self.sprite_name))
    end
    self.sprite = game.sprites[self.sprite_name]:instantiate()

    -- FIXME progress!  but this should update when the sprite changes, argh!
    if self.sprite.shape then
        -- FIXME hang on, the sprite is our own instance, why do we need to clone it at all--  oh, because Sprite doesn't actually clone it, whoops
        self.shape = self.sprite.shape:clone()
        self.shape._xxx_is_one_way_platform = self.sprite.shape._xxx_is_one_way_platform
        self.anchor = Vector.zero
        self.shape:move_to(position:unpack())
    end
end

-- Called once per update frame; any state changes should go here
function Actor:update(dt)
    self.timer = self.timer + dt
    self.sprite:update(dt)
end

-- Draw the actor
function Actor:draw()
    if self.sprite then
        local where = self.pos:clone()
        if self.is_floating then
            where.y = where.y - (math.sin(self.timer) + 1) * 4
        end
        self.sprite:draw_at(where)
    end
end

-- General API stuff for controlling actors from outside
function Actor:move_to(position)
    self.pos = position
    if self.shape then
        self.shape:move_to(position:unpack())
    end
end

function Actor:set_shape(new_shape)
    if self.shape then
        worldscene.collider:remove(self.shape)
    end
    self.shape = new_shape
    if self.shape then
        worldscene.collider:add(self.shape, self)
        self.shape:move_to(self.pos:unpack())
    end
end

function Actor:set_sprite(sprite_name)
    self.sprite_name = sprite_name
    self.sprite = game.sprites[self.sprite_name]:instantiate()
end


-- ========================================================================== --
-- MobileActor
-- Base class for an actor that's subject to standard physics
-- TODO not a fan of using subclassing for this; other options include
-- component-entity, or going the zdoom route and making everything have every
-- behavior but toggled on and off via myriad flags
local TILE_SIZE = 32

-- TODO these are a property of the world and should go on the world object
-- once one exists
local gravity = Vector(0, 768)
local terminal_velocity = 1536

local MobileActor = Actor:extend{
    __name = 'MobileActor',
    -- TODO separate code from twiddles
    velocity = nil,

    -- Passive physics parameters
    -- Units are pixels and seconds!
    min_speed = 1,
    -- FIXME i feel like this is not done well.  floating should feel floatier
    -- FIXME friction should probably be separate from deliberate deceleration?
    friction_decel = 512,
    ground_friction = 1,
    gravity_multiplier = 1,
    gravity_multiplier_down = 1,

    -- Physics state
    on_ground = false,
}

function MobileActor:blocks(actor, d)
    return true
end

function MobileActor:update(dt)
    MobileActor.__super.update(self, dt)

    -- Fudge the movement to try ending up aligned to the pixel grid.
    -- This helps compensate for the physics engine's love of gross float
    -- coordinates, and should allow the player to position themselves
    -- pixel-perfectly when standing on pixel-perfect (i.e. flat) ground.
    -- FIXME this causes us to not actually /collide/ with the ground most of
    -- the time, because initial gravity only pulls us down a little bit and
    -- then gets rounded to zero, but i guess my recent fixes to ground
    -- detection work pretty well because it doesn't seem to have any ill
    -- effects!  it makes me a little wary though so i should examine later
    -- FIXME i had to make this round to the nearest eighth because i found a
    -- place where standing on a gentle slope would make you vibrate back and
    -- forth between pixels.  i would really like to get rid of the "slope
    -- cancelling" force somehow, i think it's fucking me up
    local goalpos = self.pos + self.velocity * dt
    goalpos.x = math.floor(goalpos.x * 8 + 0.5) / 8
    goalpos.y = math.floor(goalpos.y * 8 + 0.5) / 8
    local movement = goalpos - self.pos

    -- Collision time!
    --print()
    --print()
    --print()
    --print("Collision time!  position", self.pos, "velocity", self.velocity, "movement", movement)

    -- First things first: restrict movement to within the current map
    -- TODO ARGH, worldscene is a global!
    -- FIXME hitting the bottom of the map should count as landing on solid ground
    do
        local l, t, r, b = self.shape:bbox()
        local ml, mt, mr, mb = 0, 0, worldscene.map.width, worldscene.map.height
        movement.x = util.clamp(movement.x, ml - l, mr - r)
        movement.y = util.clamp(movement.y, mt - t, mb - b)
    end

    local attempted = movement
    local movement, hits, last_clock = worldscene.collider:slide(self.shape, movement:unpack())

    -- Debugging
    if game.debug and game.debug_twiddles.show_collision then
        for shape, collision in pairs(hits) do
            if not game.debug_hits[shape] then
                game.debug_hits[shape] = collision
            end
        end
    end

    -- Ground sticking
    -- If we walk up off the top of a slope, our momentum will carry us into
    -- the air, which looks very silly.  A conscious actor would step off the
    -- ramp.  So if we're only a very short distance above the ground, we were
    -- on the ground before moving, and we're not trying to jump, then stick us
    -- to the floor.
    -- FIXME move this to SentientActor, somehow (difficulty is that i want it
    -- to add to the movement before all this other stuff happens -- although
    -- we should merge in collisions too...)
    -- XXX note that this is the only place on_ground is set to /false/, so it
    -- shouldn't only be run when not jumping or whatever
    if self.on_ground then
        -- FIXME how far should we try this?  128 is arbitrary, but works out
        -- to 2 pixels at 60fps, which...  i don't know what that means
        -- FIXME again, don't do this off the edges of the map...  depending on map behavior...  sigh
        --print("/// doing drop")
        local drop_movement, drop_hits, drop_clock = worldscene.collider:slide(self.shape, 0, 128 * dt, true)
        --print("\\\\\\ end drop")
        local any_hit = false
        for shape, collision in pairs(drop_hits) do
            hits[shape] = collision
            if collision.touchtype > 0 then
                any_hit = true
            end
        end
        if any_hit then
            -- If we hit something, then commit the movement and stick us to the ground
            movement.y = movement.y + drop_movement.y
        else
            -- Otherwise, we're in the air; ignore the drop
            self.on_ground = false
        end
    end

    self.pos = self.pos + movement
    --print("FINAL POSITION:", self.pos)
    if self.shape then
        self.shape:move_to(self.pos:unpack())
    end

    -- Tell everyone we've hit them
    -- TODO surely we should announce this in the order we hit!  all the more
    -- reason to hoist the loop out of whammo and into here
    for shape, collision in pairs(hits) do
        local actor = worldscene.collider:get_owner(shape)
        if actor then
            -- FIXME this should pass along the side the object is hit from!
            actor:on_collide(self, movement, collision)
        end
    end

    -- Ground test: did we collide with something facing upwards?
    -- Find the normal that faces /most/ upwards, i.e. most away from gravity
    local mindot = 0  -- 0 is vertical, which we don't want
    local ground
    -- FIXME this is actually wrong!  it doesn't have the same logic as the
    -- clocks, resetting if we move in a second pass
    for _, collision in pairs(hits) do
        if collision.touchtype >= 0 and not collision.clock:includes(gravity) then
            for normal, normal1 in pairs(collision.normals) do
                local dot = normal1 * gravity
                if dot < mindot then
                    mindot = dot
                    ground = normal1
                end
            end
        end
    end
    self.ground_normal = ground
    if ground then
        -- FIXME is this now redundant with ground_normal?
        self.on_ground = true
    end

    -- Trim velocity as necessary, based on the last surface we slid against
    --print("velocity is", self.velocity, "and clock is", last_clock)
    if last_clock and self.velocity ~= Vector.zero then
        local axis = last_clock:closest_extreme(self.velocity)
        if not axis then
            -- TODO stop?  once i fix the empty thing
        elseif self.velocity * axis < 0 then
            -- Nearest axis points away from our movement, so we have to stop
            self.velocity = Vector.zero:clone()
        else
            --print("axis", axis, "dot product", self.velocity * axis)
            -- Nearest axis is within a quarter-turn, so slide that direction
            --print("velocity", self.velocity, self.velocity:projectOn(axis))
            self.velocity = self.velocity:projectOn(axis)
        end
    end
    --print("and now it's", self.velocity)
    --print("movement", movement, "attempted", attempted)

    ----------------------------------------------------------------------------
    -- Passive adjustments
    -- We do these last so they don't erode an explicitly-set velocity before
    -- that velocity even has a chance to affect movement.
    if math.abs(self.velocity.x) < self.min_speed then
        self.velocity.x = 0
    end

    -- Friction -- the general tendency for everything to decelerate.
    -- It always pushes against the direction of motion, but never so much that
    -- it would reverse the motion.  Note that taking the dot product with the
    -- horizontal produces the normal force.
    -- Include the dt factor from the beginning, to make capping easier.
    -- Also, doing this before anything else ensures that it only considers
    -- deliberate movement and momentum, not gravity.
    local vellen = self.velocity:len()
    if vellen > 1e-8 then
        local friction_vector
        if self.ground_normal then
            decel_vector = self.ground_normal:perpendicular() * (self.friction_decel * dt)
            if decel_vector * self.velocity > 0 then
                decel_vector = -decel_vector
            end
            decel_vector = decel_vector:projectOn(self.velocity)
            decel_vector:trimInplace(vellen)
        else
            local vel1 = self.velocity / vellen
            decel_vector = -self.friction_decel * dt * vel1
            -- FIXME need some real air resistance; as written, this also reverses gravity, oops
            decel_vector = Vector.zero
        end
        self.velocity = self.velocity + decel_vector
        --print("velocity after deceleration:", self.velocity)
    end

    if not self.is_floating then
        -- TODO factor the ground_friction constant into this, and also into
        -- slope resistance
        -- Gravity
        local mult = self.gravity_multiplier
        if self.velocity.y > 0 then
            mult = mult * self.gravity_multiplier_down
        end
        self.velocity = self.velocity + gravity * mult * dt
        self.velocity.y = math.min(self.velocity.y, terminal_velocity)
        --print("velocity after gravity:", self.velocity)
    end

    -- FIXME this sucks
    self._stupid_hits_hack = hits
end


-- ========================================================================== --
-- SentientActor
-- An actor that makes conscious movement decisions.  This is modeled on the
-- player's own behavior, but can be used for other things as well.
-- Note that, unlike the classes above, this class changes the actor's pose.  A
-- sentient actor should have stand, walk, and fall poses at a minimum.
local SentientActor = MobileActor:extend{
    decision_jump_mode = 0,
    decision_walk = 0,

    is_dead = false,
    is_locked = false,

    -- Active physics parameters
    -- TODO these are a little goofy because friction works differently; may be
    -- worth looking at that again.
    xaccel = 1536,
    deceleration = 0.5,
    max_speed = 256,
    -- Max height of a projectile = vy² / (2g), so vy = √2gh
    -- Pick a jump velocity that gets us up 2 tiles, plus a margin of error
    jumpvel = math.sqrt(2 * gravity.y * (TILE_SIZE * 2.25)),
    jumpcap = 0.25,
    -- Multiplier for xaccel while airborne.  MUST be greater than the ratio of
    -- friction to xaccel, or the player won't be able to move while floating!
    aircontrol = 0.75,
    -- Maximum slope that can be walked up or jumped off of
    max_slope = Vector(1, -1),
    max_slope_slowdown = 0.7,
}

-- Decide to start walking in the given direction.  -1 for left, 1 for right,
-- or 0 to stop walking.  Persists until changed.
function SentientActor:decide_walk(direction)
    self.decision_walk = direction
end

-- Decide to jump.
function SentientActor:decide_jump()
    if self.is_floating then
        return
    end

    -- Jumping has three states:
    -- 2: starting to jump
    -- 1: continuing a jump
    -- 0: not jumping (i.e., falling)
    self.decision_jump_mode = 2
end

-- Decide to abandon an ongoing jump, if any, which may reduce the jump height.
function SentientActor:decide_abandon_jump()
    self.decision_jump_mode = 0
end

function SentientActor:update(dt)
    if self.is_dead or self.is_locked then
        -- Ignore conscious decisions; just apply physics
        -- FIXME i think "locked" only makes sense for the player?
        SentientActor.__super.update(self, dt)
        return
    end

    local xmult
    local max_speed = self.max_speed
    local xdir = Vector(1, 0)
    if self.on_ground then
        local uphill = self.decision_walk * self.ground_normal.x < 0
        xdir = self.ground_normal:perpendicular()
        xmult = self.ground_friction
        if uphill then
            if self.too_steep then
                xmult = 0
            else
                -- Linearly scale the slope slowdown, based on the y coordinate (of
                -- the normal, which is the x coordinate of the slope itself).
                -- This isn't mathematically correct, but it feels fine.
                local ground_y = math.abs(self.ground_normal.y)
                local max_y = math.abs(self.max_slope:normalized().y)
                local slowdown = 1 - (1 - self.max_slope_slowdown) * (1 - ground_y) / (1 - max_y)
                max_speed = max_speed * slowdown
                xmult = xmult * slowdown
            end
        end
    else
        xmult = self.aircontrol
    end
    --print()
    --print()
    --print("position", self.pos, "velocity", self.velocity)

    -- Explicit movement
    if self.decision_walk > 0 then
        -- FIXME hmm is this the right way to handle a maximum walking speed?
        -- it obviously doesn't work correctly in another frame of reference
        if self.velocity.x < max_speed then
            local dx = math.min(max_speed - self.velocity.x, self.xaccel * xmult * dt)
            self.velocity = self.velocity + dx * xdir
        end
        self.facing_left = false
    elseif self.decision_walk < 0 then
        if self.velocity.x > -max_speed then
            local dx = math.max(-max_speed - self.velocity.x, self.xaccel * xmult * dt)
            self.velocity = self.velocity - dx * xdir
        end
        self.facing_left = true
    else
        -- Not walking means we're trying to stop, albeit leisurely
        local dx = math.min(math.abs(self.velocity * xdir), self.xaccel * self.deceleration * dt)
        local dv = dx * xdir
        if dv * self.velocity < 0 then
            self.velocity = self.velocity + dv
        else
            self.velocity = self.velocity - dv
        end
    end

    -- Jumping
    -- This uses the Sonic approach: pressing jump immediately sets (not
    -- increases!) the player's y velocity, and releasing jump lowers the y
    -- velocity to a threshold
    if self.decision_jump_mode == 2 then
        self.decision_jump_mode = 1
        if self.on_ground and not self.too_steep then
            -- TODO maybe jump away from the ground, not always up?  then could
            -- allow jumping off of steep slopes
            if self.velocity.y > -self.jumpvel then
                self.velocity.y = -self.jumpvel
                self.on_ground = false
            end
        end
    elseif self.decision_jump_mode == 0 then
        if not self.on_ground then
            self.velocity.y = math.max(self.velocity.y, -self.jumpvel * self.jumpcap)
        end
    end

    -- Apply physics
    SentientActor.__super.update(self, dt)

    -- Handle our own passive physics
    if self.on_ground then
        self.too_steep = (
            self.ground_normal * gravity - self.max_slope:normalized() * gravity > 1e-8)

        -- Slope resistance -- an actor's ability to stay in place on an incline
        -- It always pushes upwards along the slope.  It has no cap, since it
        -- should always exactly oppose gravity, as long as the slope is shallow
        -- enough.
        -- Skip it entirely if we're not even moving in the general direction
        -- of gravity, though, so it doesn't interfere with jumping.
        if not self.too_steep then
            local slope = self.ground_normal:perpendicular()
            if slope * gravity > 0 then
                slope = -slope
            end
            local slope_resistance = -(gravity * slope)
            self.velocity = self.velocity + slope_resistance * dt * slope
            --print("velocity after slope resistance:", self.velocity)
        end
    else
        self.too_steep = nil
    end

    -- Update the pose
    self:update_pose()
end

-- Figure out a new pose and switch to it.  Default behavior is based on player
-- logic; feel free to override.
function SentientActor:update_pose()
    local pose = 'stand'
    if self.is_dead then
        pose = 'die'
    elseif self.is_floating then
        pose = 'fall'
    elseif self.on_ground then
        if self.decision_walk ~= 0 then
            pose = 'walk'
        end
    elseif self.velocity.y < 0 then
        pose = 'jump'
    elseif self.velocity.y > 0 then
        pose = 'fall'
    end

    self.sprite:set_facing_right(not self.facing_left)
    self.sprite:set_pose(pose)
end


return {
    BareActor = BareActor,
    Actor = Actor,
    MobileActor = MobileActor,
    SentientActor = SentientActor,
}
