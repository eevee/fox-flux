local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'

-- FIXME lol
local actors_misc2 = require 'isaacsdescent.actors.misc'


local Player = actors_base.MobileActor:extend{
    name = 'isaac',
    sprite_name = 'isaac',
    dialogue_position = 'left',
    dialogue_sprite_name = 'isaac portrait',
    z = 1000,

    is_player = true,

    inventory_cursor = 1,

    -- Conscious movement decisions
    decision_walk = 0,
    decision_jump_mode = 0,
}

function Player:init(...)
    actors_base.MobileActor.init(self, ...)

    -- TODO not sure how i feel about having player state attached to the
    -- actor, but it /does/ make sense, and it's certainly an improvement over
    -- a global
    -- TODO BUT either way, this needs to be initialized at the start of the
    -- game and correctly restored on map load
    self.inventory = {}
    table.insert(self.inventory, {
        -- TODO i feel like this should be a real type, or perhaps attached to
        -- an actor somehow, but i don't want you to have real actual actors in
        -- your inventory.  i suppose you could just have a count of actor
        -- /types/, which i think is how zdoom works?
        display_name = 'Staff of Iesus',
        sprite_name = 'staff',
        on_inventory_use = function(self, activator)
            if activator.ptrs.savepoint then
                -- TODO seems like a good place to use :die()
                worldscene:remove_actor(activator.ptrs.savepoint)
                activator.ptrs.savepoint = nil
            end

            game.resource_manager:get('assets/sounds/staff.ogg'):play()
            local savepoint = actors_misc2.Savepoint(
                -- TODO this constant is /totally/ arbitrary, hmm
                activator.pos + Vector(0, -16))
            worldscene:add_actor(savepoint)
            activator.ptrs.savepoint = savepoint
        end,
    })

end

function Player:move_to(...)
    Player.__super.move_to(self, ...)

    -- Nuke the player's touched object after an external movement, since
    -- chances are, we're not touching it any more
    -- This is vaguely hacky, but it gets rid of the dang use prompt after
    -- teleporting to the graveyard
    self.touching_mechanism = nil
end

-- "Thinking" API
-- Totally not sure about this yet, but it seems handy for critter AI.

-- Decide to start walking in the given direction.  -1 for left, 1 for right,
-- or 0 to stop walking.  Persists until changed.
function Player:decide_walk(direction)
    self.decision_walk = direction
end

-- Decide to jump.
function Player:decide_jump()
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
function Player:decide_abandon_jump()
    self.decision_jump_mode = 0
end

function Player:update(dt)
    if self.is_dead then
        -- FIXME a corpse still has physics, just not input
        self.sprite:update(dt)
        return
    end

    local xmult
    if self.on_ground then
        -- TODO adjust this factor when on a slope, so ascending is harder than
        -- descending?  maybe even affect max_speed going uphill?
        xmult = self.ground_friction
    else
        xmult = self.aircontrol
    end
    --print()
    --print()
    --print("position", self.pos, "velocity", self.velocity)

    -- Explicit movement
    -- TODO should be whichever was pressed last?
    local pose = 'stand'
    if self.decision_walk > 0 then
        -- FIXME hmm is this the right way to handle a maximum walking speed?
        -- it obviously doesn't work correctly in another frame of reference
        if self.velocity.x < self.max_speed then
            self.velocity.x = math.min(self.max_speed, self.velocity.x + self.xaccel * xmult * dt)
        end
        self.facing_left = false
        pose = 'walk'
    elseif self.decision_walk < 0 then
        if self.velocity.x > -self.max_speed then
            self.velocity.x = math.max(-self.max_speed, self.velocity.x - self.xaccel * xmult * dt)
        end
        self.facing_left = true
        pose = 'walk'
    end
    if self.is_floating then
        -- FIXME probably doesn't belong here, buut
        pose = 'fall'
    end

    -- Jumping
    -- This uses the Sonic approach: pressing jump immediately sets (not
    -- increases!) the player's y velocity, and releasing jump lowers the y
    -- velocity to a threshold
    if self.decision_jump_mode == 2 then
        self.decision_jump_mode = 1
        if self.on_ground then
            if self.velocity.y > -self.jumpvel then
                self.velocity.y = -self.jumpvel
                self.on_ground = false
                game.resource_manager:get('assets/sounds/jump.ogg'):play()
                -- FIXME gravity is applied after this and before you actually
                -- move, which means that if the framerate is too low, your
                -- initial jump velocity will be cut so much that you can't
                -- reach the maximum jump height.
                -- currently this is worked around by slicing updates in the
                -- world scene, which is probably a good idea anyway, but i
                -- think my whole ordering of actions vs passive forces needs a
                -- little tweaking.
                -- btw, walking has the same kind of problem -- friction is
                -- applied after the speed cap but before actual movement, so
                -- at a very low framerate, you move very slowly.  a real fix
                -- may need some comprehensive rearrangement of stuff
            end
        end
    elseif self.decision_jump_mode == 0 then
        if not self.on_ground then
            self.velocity.y = math.max(self.velocity.y, -self.jumpvel * self.jumpcap)
        end
    end

    -- Run the base logic to perform movement, collision, sprite updating, etc.
    actors_base.MobileActor.update(self, dt)

    -- FIXME uhh this sucks, but otherwise the death animation is clobbered by
    -- the bit below!  should death skip the rest of the actor's update cycle
    -- entirely, including activating any other collision?  should death only
    -- happen at the start of a frame?  should it be an event or something?
    if self.is_dead then
        return
    end

    -- Update pose depending on actual movement
    if self.on_ground then
    elseif self.velocity.y < 0 then
        pose = 'jump'
    elseif self.velocity.y > 0 then
        pose = 'fall'
    end
    -- TODO how do these work for things that aren't players?
    self.sprite:set_facing_right(not self.facing_left)
    self.sprite:set_pose(pose)

    -- TODO ugh, this whole block should probably be elsewhere; i need a way to
    -- check current touches anyway.  would be nice if it could hook into the
    -- physics system so i don't have to ask twice
    local hits = self._stupid_hits_hack
    -- FIXME this should really really be a ptr
    self.touching_mechanism = nil
    debug_hits = hits
    for shape in pairs(hits) do
        local actor = worldscene.collider:get_owner(shape)
        if actor and actor.is_usable then
            self.touching_mechanism = actor
            break
        end
    end

    -- TODO this is stupid but i want a real exit door anyway
    -- TODO also it should fire an event or something
    local _, _, x1, _ = self.shape:bbox()
    if x1 >= worldscene.map.width then
        self.__EXIT = true
    end

    -- A floating player spawns particles
    -- FIXME this seems a prime candidate for entity/component or something,
    -- where floatiness is a child component with its own update behavior
    -- FIXME this is hardcoded for isaac's bbox, roughly -- should be smarter
    if self.is_floating and math.random() < dt * 8 then
        worldscene:add_actor(actors_misc.Particle(
            self.pos + Vector(math.random(-16, 16), 0), Vector(0, -32), Vector(0, 0),
            {255, 255, 255}, 1.5, true))
    end
end

function Player:draw()
    actors_base.MobileActor.draw(self)

    do return end
    if self.touching_mechanism then
        love.graphics.setColor(0, 64, 255, 128)
        self.touching_mechanism.shape:draw('fill')
        love.graphics.setColor(255, 255, 255)
    end
    if self.on_ground then
        love.graphics.setColor(255, 0, 0, 128)
    else
        love.graphics.setColor(0, 192, 0, 128)
    end
    self.shape:draw('fill')
    love.graphics.setColor(255, 255, 255)
end

function Player:damage(source, amount)
    -- Apply a force that shoves the player away from the source
    -- FIXME this should maybe be using the direction vector passed to
    -- on_collide instead?  this doesn't take collision boxes into account
    local offset = self.pos - source.pos
    local force = Vector(256, -32)
    if self.pos.x < source.pos.x then
        force.x = -force.x
    end
    self.velocity = self.velocity + force
end

local Gamestate = require 'vendor.hump.gamestate'
local DeadScene = require 'klinklang.scenes.dead'
-- TODO should other things also be able to die?
function Player:die()
    if not self.is_dead then
        game.resource_manager:get('assets/sounds/die.ogg'):play()
        local pose = 'die'
        self.sprite:set_pose(pose)
        self.is_dead = true
        -- TODO LOL THIS WILL NOT FLY but the problem with putting a check in
        -- WorldScene is that it will then explode.  so maybe this should fire an
        -- event?  hump has an events thing, right?  or, maybe knife, maybe let's
        -- switch to knife...
        -- TODO oh, it gets better: switch gamestate during an update means draw
        -- doesn't run this cycle, so you get a single black frame
        worldscene.tick:delay(function()
            Gamestate.push(DeadScene())
        end, 1.5)
    end
end

function Player:resurrect()
    if self.is_dead then
        self.is_dead = false
        -- Reset physics
        self.velocity = Vector(0, 0)
        -- FIXME this sounds reasonable, but if you resurrect /in place/ it's
        -- weird to change facing direction?  hmm
        self.facing_left = false
        -- This does a collision check without moving the player, which is a
        -- clever way to check whether they're on flat ground, update their
        -- sprite, etc. before any actual movement (or input!) happens.
        -- FIXME it's possible for the player to die again here, and that
        -- screws up the scene order and won't get you a dead scene, eek!
        -- FIXME this still takes player /input/, which makes it not solve the
        -- original problem i wanted of making on_ground be correct!
        self.on_ground = false
        self:update(0)
        -- Of course, the sprite doesn't actually update until the next sprite
        -- update, dangit.
        -- FIXME seems like i could reorder update() to fix this; otherwise
        -- there's a frame delay on ANY movement that changes the sprite
        self.sprite:update(0)
    end
end


return Player
