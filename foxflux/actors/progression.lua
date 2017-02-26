local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_generic = require 'klinklang.actors.generic'
local DialogueScene = require 'klinklang.scenes.dialogue'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'

local conversations = require 'foxflux.conversations'


local StrawberryHeart = actors_base.Actor:extend{
    name = 'strawberry heart',
    sprite_name = 'strawberry heart',
    z = 9999,

    is_heart = true,

    required_form = 'rubber',
    collect_sound = 'assets/sounds/get-heart.ogg',
    is_collected = false,
    jiggle = 0,
}

function StrawberryHeart:init(pos, props)
    StrawberryHeart.__super.init(self, pos)

    if props and props['persistence key'] then
        self.persistence_key = props['persistence key']
        if game:heart(worldscene.map, self.persistence_key) then
            self.is_collected = true
            self.sprite:set_pose('collected')
        end
    end
end

function StrawberryHeart:on_collide(actor)
    if self.is_collected then
        return
    end
    if actor.is_player then
        if actor.form == self.required_form then
            game.resource_manager:get(self.collect_sound):clone():play()
            self.is_collected = true
            if self.persistence_key then
                game:set_heart(worldscene.map, self.persistence_key)
            end
            actor.inventory.strawberry_hearts = (actor.inventory.strawberry_hearts or 0) + 1
            self.sprite:set_pose('collect', function()
                worldscene:remove_actor(self)
            end)
        elseif self.jiggle == 0 then
            worldscene.fluct:to(self, 0.5, { jiggle = 6 })
                :ease('quartout')
                :oncomplete(function() self.jiggle = 0 end)
        end
    end
end

function StrawberryHeart:draw()
    local where = self.pos:clone()
    where.x = where.x + math.sin(self.jiggle * math.pi) * 2
    self.sprite:draw_at(where)
end


local SlimeHeart = StrawberryHeart:extend{
    name = 'slime heart',
    sprite_name = 'slime heart',

    required_form = 'slime',
    collect_sound = 'assets/sounds/get-heart-slime.ogg',
}

local GlassHeart = StrawberryHeart:extend{
    name = 'glass heart',
    sprite_name = 'glass heart',

    required_form = 'glass',
    collect_sound = 'assets/sounds/get-heart-glass.ogg',
}

local StoneHeart = StrawberryHeart:extend{
    name = 'stone heart',
    sprite_name = 'stone heart',

    required_form = 'stone',
    --collect_sound = 'assets/sounds/get-heart-glass.ogg',
}


local BossDoor = actors_base.Actor:extend{
    z = -9999,
    is_usable = true,

    is_unlocked = false,
}

function BossDoor:init(...)
    BossDoor.__super.init(self, ...)

    if game:flag(self.boss_door_flag) then
        self:unlock()
    end
end

function BossDoor:unlock()
    self.is_unlocked = true
    self.sprite:set_pose('unlocked')
    game:set_flag(self.boss_door_flag)
end

function BossDoor:on_use(activator)
    -- FIXME need to check hearts from the current zone!!
    local unlocked = self.is_unlocked
    if not unlocked then
        -- Check whether we have enough hearts yet
        local heartct = 0
        for map_path, hearts in pairs(game.progress.hearts[worldscene.map:prop('region', '')]) do
            for heart, collected in pairs(hearts) do
                if collected then
                    heartct = heartct + 1
                end
            end
        end
        if heartct >= 69 then
            unlocked = true
        end
    end

    if unlocked then
        if not self.is_unlocked then
            self:unlock()
        end
        -- TODO sound for this?
        -- TODO transition, etc...
        local map = game.resource_manager:load(self.boss_door_map)
        worldscene:load_map(map)
    else
        local candidates = conversations.insufficient_hearts[activator.form]
        -- TODO it would be nice to use...  something? here to avoid immediate repeats
        local i = math.random(1, #candidates)
        Gamestate.push(DialogueScene({ lexy = activator }, candidates[i]))
    end
end

local ForestBossDoor = BossDoor:extend{
    name = 'forest boss door',
    sprite_name = 'forest boss door',
    boss_door_flag = 'unlocked forest boss door',
    boss_door_map = 'data/maps/forest-boss.tmx.json',
}

local TechBossDoor = BossDoor:extend{
    name = 'tech boss door',
    sprite_name = 'tech boss door',
    boss_door_flag = 'unlocked forest boss door',
    boss_door_map = 'data/maps/tech-boss.tmx.json',
}


local BlastDoor = actors_generic.GenericSlidingDoor:extend{
    name = 'blast door',
    sprite_name = 'blast door',
    door_width = 24,
}
local BlastDoorShutter = actors_generic.GenericSlidingDoorShutter:extend{
    name = 'blast door shutter',
    sprite_name = 'blast door shutter',
    door_type = BlastDoor,
}


local LockScreen = actors_base.Actor:extend{
    name = 'lock screen',
    sprite_name = 'lock screen',
    is_usable = true,
}

function LockScreen:on_enter()
    LockScreen.__super.on_enter(self)

    if game:flag('opened forest blast door') then
        self.sprite:set_pose('unlocked')
        self.is_usable = false
        for _, actor in ipairs(worldscene.actors) do
            if actor:isa(BlastDoorShutter) then
                actor:open_instant()
            end
        end
    end
end

function LockScreen:blocks()
    return false
end

function LockScreen:on_use(activator)
    if not activator.is_player then
        return
    end

    if self.sprite.pose == 'locked' then
        if not game:flag('has forest passcode') then
            local candidates = conversations.need_passcode[activator.form]
            local i = math.random(1, #candidates)
            Gamestate.push(DialogueScene({ lexy = activator }, candidates[i]))
            return
        end
        game:set_flag('opened forest blast door')
        game.resource_manager:get('assets/sounds/boopbeep.ogg'):play()
        self.sprite:set_pose('unlocked')
        self.is_usable = false
        -- FIXME blah, blah, do this better
        for _, actor in ipairs(worldscene.actors) do
            if actor:isa(BlastDoorShutter) then
                actor:open()
            end
        end
    end
end


return {
    StrawberryHeart = StrawberryHeart,
}
