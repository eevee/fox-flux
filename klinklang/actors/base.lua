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
function BareActor:on_collide(actor, movement, collision)
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

local function _is_vector_almost_zero(v)
    return math.abs(v.x) < 1e-8 and math.abs(v.y) < 1e-8
end

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
    -- If this is false, then other objects will never stop this actor's
    -- movement; however, it can still push and carry them
    is_blockable = true,
    -- Pushing and platform behavior
    is_pushable = false,
    can_push = true,
    is_portable = true,  -- Can this be carried?
    can_carry = false,  -- Can this carry?
    mass = 1,  -- Pushing a heavier object will slow you down
    cargo = nil,  -- Set of currently-carried objects

    -- Physics state
    on_ground = false,
}

function MobileActor:on_enter()
    self.cargo = setmetatable({}, { __mode = 'k' })
end

function MobileActor:blocks(actor, d)
    return true
end

-- Lower-level function passed to the collider to determine whether another
-- object blocks us
-- FIXME now that they're next to each other, these two methods look positively silly!  and have a bit of a symmetry problem: the other object can override via the simple blocks(), but we have this weird thing
function MobileActor:on_collide_with(actor, collision)
    if collision.touchtype < 0 then
        -- Objects we're overlapping are always passable
        return true
    end

    -- One-way platforms only block us when we collide with an
    -- upwards-facing surface.  Expressing that correctly is hard.
    -- FIXME un-xxx this
    if collision.shape._xxx_is_one_way_platform then
        local faces_up = false
        for normal in pairs(collision.normals) do
            if normal * gravity < 0 then
                faces_up = true
                break
            end
        end
        if not faces_up then
            return true
        end
    end

    -- Otherwise, fall back to trying blocks(), if the other thing is an actor
    -- TODO is there any reason not to just merge blocks() with on_collide()?
    if actor and not actor:blocks(self, collision) then
        return true
    end

    -- Otherwise, we're blocked!
    return false
end


function MobileActor:_collision_callback(collision, pushers, already_hit)
    local actor = worldscene.collider:get_owner(collision.shape)
    if type(actor) ~= 'table' or not Object.isa(actor, BareActor) then
        actor = nil
    end

    -- Only announce a hit once per frame
    local hit_this_actor = already_hit[actor]
    if actor and not hit_this_actor then
        -- FIXME movement is fairly misleading and i'm not sure i want to
        -- provide it, at least not in this order
        actor:on_collide(self, movement, collision)
        already_hit[actor] = true
    end

    -- Debugging
    if game.debug and game.debug_twiddles.show_collision then
        game.debug_hits[collision.shape] = collision
    end

    -- FIXME again, i would love a better way to expose a normal here.
    -- also maybe the direction of movement is useful?
    local passable = self:on_collide_with(actor, collision)

    -- Pushing
    if actor and not pushers[actor] and collision.touchtype >= 0 and not passable and (
        (actor.is_pushable and self.can_push) or
        -- This allows a carrier to pick up something by rising into it
        -- FIXME check that it's pushed upwards?
        -- FIXME this is such a weird fucking case though
        (actor.is_portable and self.can_carry and not self.cargo[actor]))
    then
        local nudge = collision.attempted - collision.movement
        -- Only push in the direction the collision occurred!  If several
        -- directions, well, just average them
        local axis = Vector()
        local normalct = 0
        for normal in pairs(collision.normals) do
            normalct = normalct + 1
            axis = axis + normal
        end
        if normalct > 0 then
            nudge = nudge:projectOn(axis / normalct)
        else
            nudge = Vector.zero
        end
        if already_hit[actor] == 'nudged' or _is_vector_almost_zero(nudge) then
            -- If we've already pushed this object once, OR if we're not
            -- actually trying to push it at all, return a special value
            -- that means to trim our movement but pretend we're not
            -- blocked in that direction, so the caller doesn't cut our
            -- velocity
            already_hit[actor] = 'nudged'
            passable = false
        else
            -- TODO the mass thing is pretty cute, but it doesn't chain --
            -- the player moves the same speed pushing one crate as pushing
            -- five of them
            local actual = actor:nudge(nudge * math.min(1, self.mass / actor.mass), pushers)
            if _is_vector_almost_zero(actual) then
                -- Cargo is blocked, so we can't move either
                already_hit[actor] = 'blocked'
                passable = false
            else
                already_hit[actor] = 'nudged'
                passable = 'retry'
            end
        end
    end

    if not self.is_blockable and not passable then
        return true
    else
        return passable
    end
end

-- Move some distance, respecting collision.
-- No other physics like gravity or friction happen here; only the actual movement.
-- FIXME a couple remaining bugs:
-- - delete a bunch of prints and add some more comments
-- - i need to have a serious think about what can push/carry what!
-- - i had to disable ground sticking
-- - player briefly falls when standing on a crate moving downwards -- one frame?
-- - what's the difference between carry and push, if a carrier can push?
function MobileActor:nudge(movement, pushers, xxx_no_slide)
    pushers = pushers or {}
    pushers[self] = true

    -- Set up the hit callback, which also tells other actors that we hit them
    local already_hit = {}
    local pass_callback = function(collision)
        return self:_collision_callback(collision, pushers, already_hit)
    end

    -- Main movement loop!  Try to slide in the direction of movement; if that
    -- fails, then try to project our movement along a surface we hit and
    -- continue, until we hit something head-on or run out of movement.
    local total_movement = Vector.zero
    local hits, last_clock
    local stuck_counter = 0
    while true do
        local successful
        successful, hits = worldscene.collider:slide(self.shape, movement, pass_callback)
        self.shape:move(successful:unpack())
        self.pos = self.pos + successful
        total_movement = total_movement + successful

        if xxx_no_slide then
            break
        end
        local remaining = movement - successful
        -- FIXME these values are completely arbitrary and i cannot justify them
        if math.abs(remaining.x) < 1/16 and math.abs(remaining.y) < 1/16 then
            break
        end

        local combined_clock = util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
        for shape, collision in pairs(hits) do
            if not collision.passable then
                combined_clock:intersect(collision.clock)
            end
        end

        -- Slide along the extreme that's closest to the direction of movement
        -- TODO combined_clock is ONLY used for this.  removing it is within my
        -- grasp at last
        local slide = combined_clock:closest_extreme(movement)
        if not slide or slide == Vector.zero then
            break
        end
        if remaining * slide < 0 then
            -- Can't slide anywhere near the direction of movement, so we
            -- have to stop here
            break
        end
        movement = remaining:projectOn(slide)

        if math.abs(movement.x) < 1/16 and math.abs(movement.y) < 1/16 then
            break
        end

        -- Automatically break if we don't move for three iterations -- not
        -- moving once is okay because we might slide, but three indicates a
        -- bad loop somewhere
        if _is_vector_almost_zero(successful) then
            stuck_counter = stuck_counter + 1
            if stuck_counter >= 3 then
                print("!!!  BREAKING OUT OF LOOP BECAUSE WE'RE STUCK, OOPS")
                break
            end
        end
    end

    local last_clock = util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
    for shape, collision in pairs(hits) do
        -- FIXME this is /slightly/ clumsy...  ehh...
        local owner = worldscene.collider:get_owner(shape)
        if not collision.passable and (not owner or already_hit[owner] ~= 'nudged') then
            last_clock:intersect(collision.clock)
        end
    end

    --print("FINAL POSITION:", self.pos)

    -- Move our cargo along with us, independently of their own movement
    -- FIXME this means our momentum isn't part of theirs.  is that bad?
    if self.can_carry and self.cargo and not _is_vector_almost_zero(total_movement) then
        for actor in pairs(self.cargo) do
            if not pushers[actor] and already_hit[actor] ~= 'nudged' then
                actor:nudge(total_movement, pushers)
            end
        end
    end

    pushers[self] = nil
    return total_movement, hits, last_clock
end

-- Given a list of hits from the collider, check whether we're standing on the
-- ground.  Broken out so SentientActor can use it for shenanigans.
function MobileActor:check_for_ground(hits)
    -- Ground test: did we collide with something facing upwards?
    -- Find the normal that faces /most/ upwards, i.e. most away from gravity
    local mindot = 0  -- 0 is vertical, which we don't want
    local ground, ground_collision
    for _, collision in pairs(hits) do
        if collision.touchtype >= 0 and not collision.passable and not collision.clock:includes(gravity) then
            for normal, normal1 in pairs(collision.normals) do
                local dot = normal1 * gravity
                if dot < mindot then
                    mindot = dot
                    ground = normal1
                    ground_collision = collision
                end
            end
        end
    end
    self.ground_normal = ground
    -- FIXME this is redundant, i **think**
    self.on_ground = not not ground

    -- Figure out what we're riding on, if anything
    local ground_actor
    if ground_collision and self.is_portable then
        ground_actor = worldscene.collider:get_owner(ground_collision.shape)
        if ground_actor and not ground_actor.can_carry then
            ground_actor = nil
        end
    end
    if self.ptrs.cargo_of ~= ground_actor then
        if self.ptrs.cargo_of then
            self.ptrs.cargo_of.cargo[self] = nil
            self.ptrs.cargo_of = nil
        end
        if ground_actor then
            ground_actor.cargo[self] = true
            self.ptrs.cargo_of = ground_actor
        end
    end

end

function MobileActor:update(dt)
    MobileActor.__super.update(self, dt)

    -- Fudge the movement to try ending up aligned to the pixel grid.
    -- This helps compensate for the physics engine's love of gross float
    -- coordinates, and should allow the player to position themselves
    -- pixel-perfectly when standing on pixel-perfect (i.e. flat) ground.
    -- FIXME i had to make this round to the nearest eighth because i found a
    -- place where standing on a gentle slope would make you vibrate back and
    -- forth between pixels.  i would really like to get rid of the "slope
    -- cancelling" force somehow, i think it's fucking me up
    local goalpos = self.pos + self.velocity * dt
    if self.velocity.x ~= 0 then
        goalpos.x = math.floor(goalpos.x * 8 + 0.5) / 8
    end
    if self.velocity.y ~= 0 then
        goalpos.y = math.floor(goalpos.y * 8 + 0.5) / 8
    end
    local movement = goalpos - self.pos

    -- Collision time!
    --print()
    --print()
    --print()
    --print("Collision time!  position", self.pos, "velocity", self.velocity, "movement", movement)
    local attempted = movement

    local movement, hits, last_clock = self:nudge(movement)
    --print("# got clock", last_clock)

    self:check_for_ground(hits)

    -- Trim velocity as necessary, based on the last surface we slid against
    -- TODO this is the only place we use last_clock!
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

    return movement, hits, last_clock
end


-- ========================================================================== --
-- SentientActor
-- An actor that makes conscious movement decisions.  This is modeled on the
-- player's own behavior, but can be used for other things as well.
-- Note that, unlike the classes above, this class changes the actor's pose.  A
-- sentient actor should have stand, walk, and fall poses at a minimum.

local function get_jump_velocity(height)
    -- Max height of a projectile = vy² / (2g), so vy = √2gh
    -- Throw in a little margin of error too
    return math.sqrt(2 * gravity.y * height * 1.125)
end

local SentientActor = MobileActor:extend{
    __name = 'SentientActor',

    -- Active physics parameters
    can_carry = true,
    can_push = true,
    is_pushable = true,
    -- TODO these are a little goofy because friction works differently; may be
    -- worth looking at that again.
    xaccel = 1536,
    deceleration = 0.5,
    max_speed = 192,
    -- Pick a jump velocity that gets us up 2 tiles, plus a margin of error
    jumpvel = get_jump_velocity(TILE_SIZE * 2),
    jumpcap = 0.25,
    -- Multiplier for xaccel while airborne.  MUST be greater than the ratio of
    -- friction to xaccel, or the player won't be able to move while floating!
    aircontrol = 0.5,
    -- Maximum slope that can be walked up or jumped off of
    max_slope = Vector(1, -1),
    max_slope_slowdown = 0.7,

    -- Other configuration
    jump_sound = nil,  -- Path!

    -- State
    decision_jump_mode = 0,
    decision_walk = 0,
    is_dead = false,
    is_locked = false,
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
        return SentientActor.__super.update(self, dt)
    end

    local xmult
    local max_speed = self.max_speed
    local xdir = Vector(1, 0)
    if self.on_ground then
        local uphill = self.decision_walk * self.ground_normal.x < 0
        -- This looks a bit more convoluted than just moving the player right
        -- and letting sliding take care of it, but it means that walking
        -- /down/ a slope will actually walk us along it
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
            local dx = math.min(max_speed + self.velocity.x, self.xaccel * xmult * dt)
            self.velocity = self.velocity - dx * xdir
        end
        self.facing_left = true
    elseif not self.too_steep then
        -- Not walking means we're trying to stop, albeit leisurely
        local dx = math.min(math.abs(self.velocity * xdir), self.xaccel * self.deceleration * xmult * dt)
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
        if self.on_ground then
            -- TODO maybe jump away from the ground, not always up?  then could
            -- allow jumping off of steep slopes
            local jumped
            if self.too_steep then
                self.velocity = self.jumpvel * self.ground_normal
                jumped = true
            elseif self.velocity.y > -self.jumpvel then
                self.velocity.y = -self.jumpvel
                jumped = true
            end

            if jumped and self.jump_sound then
                game.resource_manager:get(self.jump_sound):clone():play()
            end
        end
    elseif self.decision_jump_mode == 0 then
        if not self.on_ground then
            self.velocity.y = math.max(self.velocity.y, -self.jumpvel * self.jumpcap)
        end
    end

    -- Apply physics
    local was_on_ground = self.on_ground
    local movement, hits, last_clock = SentientActor.__super.update(self, dt)

    -- Ground sticking
    -- If we walk up off the top of a slope, our momentum will carry us into
    -- the air, which looks very silly.  A conscious actor would step off the
    -- ramp.  So if we're only a very short distance above the ground, we were
    -- on the ground before moving, and we're not trying to jump, then stick us
    -- to the floor.
    -- Note that we commit to the short drop even if we don't actually hit the
    -- ground!  Since a nudge can cause both pushes and callbacks, there's no
    -- easy way to do a hypothetical slide without just doing it twice.  This
    -- should be fine, though, since it ought to only happen for a single
    -- frame, and is only a short distance.
    -- TODO this doesn't do velocity sliding afterwards, though that's not such
    -- a big deal since it'll happen the next frame
    -- TODO i suspect this could be avoided with the same (not yet written)
    -- logic that would keep critters from walking off of ledges?  or if
    -- the loop were taken out of collider.slide and put in here, so i could
    -- just explicitly slide in a custom direction
    if was_on_ground and not self.on_ground and self.decision_jump_mode == 0 then
        -- If we run uphill along our steepest uphill slope and it immediately
        -- becomes our steepest downhill slope, we'll need to drop the
        -- x-coordinate of the normal, twice
        -- FIXME take max_speed into account here too so you can still be
        -- launched -- though i think that will look mighty funny since the
        -- drop will still happen
        local drop = Vector(0, movement:len() * math.abs(self.max_slope.x) * 2)
        local drop_movement
        drop_movement, hits, last_clock = self:nudge(drop, nil, true)
        movement = movement + drop_movement
        self:check_for_ground(hits)
    end

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

    return movement, hits, last_clock
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
    get_jump_velocity = get_jump_velocity,
}
