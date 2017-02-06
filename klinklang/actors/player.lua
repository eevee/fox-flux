local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local Player = actors_base.SentientActor:extend{
    name = 'lexy',
    sprite_name = 'lexy: rubber',
    dialogue_position = 'left',
    dialogue_sprite_name = 'lexy portrait',
    z = 1000,

    is_player = true,

    inventory_cursor = 1,

    -- Conscious movement decisions
    decision_walk = 0,
    decision_jump_mode = 0,
}

function Player:init(...)
    Player.__super.init(self, ...)

    -- TODO not sure how i feel about having player state attached to the
    -- actor, but it /does/ make sense, and it's certainly an improvement over
    -- a global
    -- TODO BUT either way, this needs to be initialized at the start of the
    -- game and correctly restored on map load
    self.inventory = {}
    table.insert(self.inventory, {
        display_name = 'Compact',
        sprite_name = 'compact',
        description = 'Your compact.  You never leave home without it!',
        on_inventory_use = function(self, activator)
            -- TODO menu for who to dial?  later, when robin exists
            -- FIXME need a better way to specify an actor class as a speaker
            local actors_npcs = require 'foxflux.actors.npcs'
            local Gamestate = require 'vendor.hump.gamestate'
            local DialogueScene = require 'klinklang.scenes.dialogue'
            Gamestate.push(DialogueScene({
                lexy = activator,
                cerise = actors_npcs.Cerise,
            }, {
                { "Hey, sweetie!\nHere are a few more\nlines of text\njust for you!", speaker = 'cerise' },
                { "Oh, hey.", speaker = 'lexy' },
            }))
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

function Player:update(dt)
    -- FIXME testing purposes only!!
    if not self.is_stone and love.keyboard.isDown('s') then
        self.is_stone = true
        self.gravity_multiplier = 2
        self.decision_walk = 0
        self.aircontrol = 0.5
    end
    if self.name == 'lexy' and not self.is_stone and love.keyboard.isDown('d') then
        self.sprite_name = 'lexy: pooltoy'
        self.sprite = game.sprites[self.sprite_name]:instantiate()
        self.dialogue_sprite_name = 'lexy portrait: rubber'
    end

    -- Run the base logic to perform movement, collision, sprite updating, etc.
    Player.__super.update(self, dt)

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

function Player:on_collide(actor, direction)
    if self.sprite_name == 'lexy: rubber' and actor.name == 'slime' and math.abs(actor.pos.y - (self.pos.y - 12)) < 4 then
        worldscene:remove_actor(actor)
        self.locked = true
        self.sprite_name = 'lexy: slime tf'
        self.sprite = game.sprites[self.sprite_name]:instantiate()
        -- FIXME DO AT END OF ANIMATION
        worldscene.tick:delay(function()
            self.locked = false
            self.sprite_name = 'lexy: slime'
            self.sprite = game.sprites[self.sprite_name]:instantiate()
            self.dialogue_sprite_name = 'lexy portrait: slime'
        end, 0.85)
    end
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
