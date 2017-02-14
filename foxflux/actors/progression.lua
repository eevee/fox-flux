local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_generic = require 'klinklang.actors.generic'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local StrawberryHeart = actors_base.Actor:extend{
    name = 'strawberry heart',
    sprite_name = 'strawberry heart',
    z = 9999,

    is_collected = false,
}

function StrawberryHeart:on_collide(actor)
    if self.is_collected then
        return
    end
    if actor.is_player and actor.sprite_name == 'lexy: rubber' then
        game.resource_manager:get('assets/sounds/get-heart.ogg'):clone():play()
        self.is_collected = true
        actor.inventory.strawberry_hearts = (actor.inventory.strawberry_hearts or 0) + 1
        self.sprite:set_pose('collect', function()
            worldscene:remove_actor(self)
        end)
    end
end


local SlimeHeart = actors_base.Actor:extend{
    name = 'slime heart',
    sprite_name = 'slime heart',
    z = 9999,

    is_collected = false,
}

function SlimeHeart:on_collide(actor)
    if self.is_collected then
        return
    end
    if actor.is_player and actor.sprite_name == 'lexy: slime' then
        game.resource_manager:get('assets/sounds/get-heart-slime.ogg'):clone():play()
        self.is_collected = true
        actor.inventory.strawberry_hearts = (actor.inventory.strawberry_hearts or 0) + 1
        self.sprite:set_pose('collect', function()
            worldscene:remove_actor(self)
        end)
    end
end


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

function LockScreen:blocks()
    return false
end

function LockScreen:on_use(activator)
    if activator.is_player and self.sprite.pose == 'locked' then
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
