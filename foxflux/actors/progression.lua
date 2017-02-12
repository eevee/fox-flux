local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local StrawberryHeart = actors_base.Actor:extend{
    name = 'strawberry heart',
    sprite_name = 'strawberry heart',
    z = 1000,

    is_collected = false,
}

function StrawberryHeart:on_collide(actor)
    if self.is_collected then
        return
    end
    if actor.is_player then
        self.is_collected = true
        actor.inventory.strawberry_hearts = (actor.inventory.strawberry_hearts or 0) + 1
        self.sprite:set_pose('collect', function()
            worldscene:remove_actor(self)
        end)
    end
end


local BossDoor = actors_base.Actor:extend{
    name = 'boss door',
    sprite_name = 'boss door',
}


local LevelDoor = actors_base.Actor:extend{
    name = 'level door',
    sprite_name = 'level door',
}


return {
    StrawberryHeart = StrawberryHeart,
}
