local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Object = require 'klinklang.object'
local tiledmap = require 'klinklang.tiledmap'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'

local conversations = require 'foxflux.conversations'


local GlassShard1 = actors_base.MobileActor:extend{
    name = 'glass shard 1',
    sprite_name = 'glass shard 1',
}

function GlassShard1:blocks()
    return false
end

function GlassShard1:on_collide_with(actor, ...)
    if actor and actor.is_player then
        return true
    end
    return GlassShard1.__super.on_collide_with(self, actor, ...)
end

function GlassShard1:update(dt)
    GlassShard1.__super.update(self, dt)
    if self.timer > 4 then
        worldscene:remove_actor(self)
    end
end

function GlassShard1:draw()
    love.graphics.push('all')
    love.graphics.setColor(255, 255, 255, math.min(1, 3 - self.timer) * 255)
    GlassShard1.__super.draw(self)
    love.graphics.pop()
end

local GlassShard2 = GlassShard1:extend{
    name = 'glass shard 2',
    sprite_name = 'glass shard 2',
}
local GlassShard3 = GlassShard1:extend{
    name = 'glass shard 3',
    sprite_name = 'glass shard 3',
}


local Player = actors_base.SentientActor:extend{
    name = 'lexy',
    sprite_name = 'lexy',
    dialogue_position = 'left',
    dialogue_sprite_variants = {
        rubber = {
            { name = 'body', sprite_name = 'lexy portrait: rubber - body' },
            { name = 'head', sprite_name = 'lexy portrait: rubber - head', while_talking = { neutral = 'talking' } },
            { name = 'eyes', sprite_name = 'lexy portrait: rubber - eyes' },
            { name = 'blush', sprite_name = 'lexy portrait: rubber - blush', default = false },
            { name = 'sweat', sprite_name = 'lexy portrait: rubber - sweat', default = false },
            compact = { body = 'compact', eyes = 'down' },
            -- TODO i wish this could be contextual?
            ['compact sweatdrop'] = { blush = false, sweat = 'default', eyes = 'down lidded' },
            blush = { blush = 'default' },
            ['no blush'] = { blush = false },
            paper = { body = 'paper' },
        },
        slime = {
            { name = 'body', sprite_name = 'lexy portrait: slime - body' },
            { name = 'head', sprite_name = 'lexy portrait: slime - head', while_talking = { neutral = 'talking' } },
            { name = 'eyes', sprite_name = 'lexy portrait: slime - eyes', default = false },
            compact = { body = 'compact', eyes = 'down' },
            paper = { body = 'paper', eyes = 'down' },
        },
        glass = {
            { name = 'body', sprite_name = 'lexy portrait: glass' },
            compact = { body = 'compact' },
            paper = { body = 'paper' },
        },
    },
    dialogue_chatter_sound = 'assets/sounds/chatter-lexy-rubber.ogg',
    dialogue_color = {255, 255, 255},
    dialogue_shadow = {135, 22, 70},
    z = 1000,
    is_portable = true,
    is_pushable = true,
    can_push = true,

    is_player = true,

    inventory_cursor = 1,
    shatter_height = 4,
    camera_jitter = 0,

    jump_sound = 'assets/sounds/jump.ogg',
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
            local convo = conversations.pick_topical_conversation()
            Gamestate.push(DialogueScene({
                lexy = activator,
                cerise = actors_npcs.Cerise,
            }, convo))
        end,
    })

    self:transform('rubber')
end

function Player:on_enter()
    Player.__super.on_enter(self)
    self.in_spikes = setmetatable({}, { __mode = 'k' })
end

function Player:on_leave()
    self.in_spikes = nil
end

function Player:move_to(...)
    Player.__super.move_to(self, ...)

    -- Nuke the player's touched object after an external movement, since
    -- chances are, we're not touching it any more
    -- This is vaguely hacky, but it gets rid of the dang use prompt after
    -- teleporting to the graveyard
    self.touching_mechanism = nil
end

function Player:on_collide_with(actor, collision, ...)
    if actor and actor.is_usable then
        -- FIXME this should really really be a ptr
        self.touching_mechanism = actor
    end

    local passable = Player.__super.on_collide_with(self, actor, collision, ...)

    -- Shatter if we hit something too fast, where "too fast" is defined as the
    -- jump height required to go up N tiles (or, equivalently, the speed we'll
    -- be moving when we hit the ground after falling N tiles).  If we hit a
    -- tile, it can have a 'hardness' property, which will modify N.
    -- FIXME "not is_locked" seems like a chumpy way to avoid interfering with cutscenes, including this one.  or maybe it's the right thing
    if self.form == 'glass' and not self.is_locked and not passable and collision.touchtype > 0 then
        local shatter_height = self.shatter_height
        local owner = worldscene.collider:get_owner(collision.shape)
        local hardness = 0
        if actor then
            hardness = actor.hardness or 0
        elseif owner and type(owner) == 'table' and owner.isa and owner:isa(tiledmap.TiledTile) then
            hardness = owner:prop('hardness') or 0
        end
        shatter_height = shatter_height - hardness

        local shatter_speed = actors_base.get_jump_velocity((shatter_height - 0.5) * game.TILE_SIZE)
        local collision_speed = 0
        for normal, normal1 in pairs(collision.normals) do
            -- We're moving into the normal, so the dot product should be negative!
            -- XXX observe that if you fall onto a slope, you get normals for
            -- BOTH the slope and your own flat bottom edge...  though i'm not
            -- sure that's wrong, exactly...
            collision_speed = math.max(collision_speed, -(self.velocity * normal1))
        end
        if collision_speed > shatter_speed then
            game.resource_manager:get('assets/sounds/shatter.ogg'):play()
            for _, actor_class in ipairs{GlassShard1, GlassShard2, GlassShard3} do
                local shard = actor_class(self.pos)
                shard.velocity = Vector(util.random_float(-192, 192), util.random_float(-128, -64))
                worldscene:add_actor(shard)
            end
            self:play_transform_cutscene('rubber', self.facing_left, 'lexy: glass revert')
        end
    end

    return passable
end

function Player:update(dt)
    if self.form == 'rubber' then
        local in_any_spikes = false
        for poker, impaled in pairs(self.in_spikes) do
            if impaled then
                in_any_spikes = true
                break
            end
        end
        if in_any_spikes then
            self.velocity.x = 0
            self.decision_walk = 0
        end
    end

    if self.form == 'slime' then
        -- Slime can hold onto ladders, but just falls straight down all the way
        self.xxx_useless_climb = true
    else
        self.xxx_useless_climb = false
    end

    if self.form == 'stone' then
        -- Stone can't hold onto ladders
        self.decision_climb = nil

        -- Stone can't move along the ground
        if self.on_ground then
            self.decision_walk = 0
        end
    end

    -- Run the base logic to perform movement, collision, sprite updating, etc.
    self.touching_mechanism = nil
    local was_on_ground = self.on_ground
    local movement, hits, last_clock = Player.__super.update(self, dt)

    -- Create a thud if we land on something
    if self.form == 'stone' and
        not was_on_ground and self.on_ground and
        self.camera_jitter == 0
    then
        game.resource_manager:get('assets/sounds/thud.ogg'):clone():play()
        worldscene.fluct:to(self, 0.25, { camera_jitter = 10 })
            :oncomplete(function() self.camera_jitter = 0 end)
    end

    -- Stop tracking spikes we're no longer touching
    for poker in pairs(self.in_spikes) do
        if not hits[poker.shape] then
            self.in_spikes[poker] = nil
        end
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

function Player:update_pose()
    -- FIXME i'm doing this because i change pose and also lock myself in
    -- mid-collision for cutscene purposes; maybe it should be a general rule?
    if self.is_locked then
        return
    end

    if self.form == 'stone' then
        self.sprite:set_pose('stand')
        return
    end

    Player.__super.update_pose(self)
end

function Player:is_transformable()
    -- is_locked is a cheap way to check whether we're in the middle of
    -- transforming into something already
    return self.form == 'rubber' and not self.is_locked
end

-- Change form instantly (does NOT do cutscenes etc)
function Player:transform(form)
    if self.form and form == 'rubber' and form ~= self.form then
        conversations.unlock_topic(self.form .. ' revert')
    end

    self.form = form
    self.inventory_frame_sprite_name = 'inventory frame: ' .. form
    self:set_sprite('lexy: ' .. form)
    self.dialogue_sprites = self.dialogue_sprite_variants[form]
    self.dialogue_background = ('assets/images/dialoguebox-lexy-%s.png'):format(form)

    if form == 'slime' then
        self.dialogue_color = {238, 255, 169}
        self.dialogue_shadow = {19, 157, 8}
        self.jump_sound = 'assets/sounds/jump-slime.ogg'
    elseif form == 'glass' then
        self.dialogue_color = {255, 255, 255}
        self.dialogue_shadow = {123, 123, 123}
        self.jump_sound = 'assets/sounds/jump-glass.ogg'
    elseif form == 'stone' then
        self.jump_sound = 'assets/sounds/jump-stone.ogg'
    else
        self.dialogue_color = {255, 255, 255}
        self.dialogue_shadow = {135, 22, 70}
        self.jump_sound = Player.jump_sound
    end

    if form == 'glass' then
        self.mass = 0.5
    elseif form == 'stone' then
        self.mass = 10
    else
        self.mass = 1
    end

    if form == 'stone' then
        self.xaccel = Player.xaccel / 2
        self.max_speed = Player.max_speed / 2
        self.jumpvel = actors_base.get_jump_velocity(32)
        self.ground_friction = math.huge
        -- TODO lower max slope too?
    else
        self.xaccel = Player.xaccel
        self.max_speed = Player.max_speed
        self.jumpvel = Player.jumpvel
        self.ground_friction = Player.ground_friction
    end

    conversations.unlock_topic(form)
end

function Player:draw()
    Player.__super.draw(self)

    -- This is a /little/ complicated.
    -- Spikes draw below us.  But for rubber, we want to show them poking
    -- through us slightly; for slime, we want to show them inside us, even if
    -- we didn't land on them.
    if self.form == 'rubber' or self.form == 'slime' then
        love.graphics.push('all')
        if self.form == 'slime' then
            love.graphics.setColor(255, 255, 255, 0.5 * 255)
        elseif self.form == 'rubber' then
            -- Draw the spikes, but scissor them and draw them slightly lower,
            -- so they look like they stick through us.
            local topleft = self.pos - self.sprite.anchor - worldscene.camera
            local sw, sh = self.sprite:getDimensions()
            love.graphics.setScissor(topleft.x, topleft.y, sw, sh * 0.65)
            love.graphics.translate(0, 2)
        end
        for poker, impaled in pairs(self.in_spikes) do
            if impaled or self.form == 'slime' then
                poker:draw()
            end
        end
        love.graphics.pop()
    end
end

function Player:play_transform_cutscene(form, facing_left, sprite_name, onfinish)
    self.is_locked = true
    self.facing_left = facing_left
    self.sprite:set_facing_right(not facing_left)
    self:set_sprite(sprite_name)
    self.sprite:set_pose('default', function()
        self.is_locked = false
        self:transform(form)
        if onfinish then
            onfinish()
        end
    end)
end

function Player:toast()
    if self.form == 'slime' and not self.is_locked then
        self:play_transform_cutscene('rubber', self.facing_left, 'lexy: slime revert')
    end
end

function Player:poke(spikes, collision)
    -- Track spikes we're currently touching, and whether we're impaled
    self.in_spikes[spikes] = actors_base.any_normal_faces(collision, Vector(0, -1))
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
