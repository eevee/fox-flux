local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local StrawberryHeart = actors_base.Actor:extend{
    name = 'strawberry heart',
    sprite_name = 'strawberry heart',

    z = 1000,
}

function StrawberryHeart:on_collide(actor)
    if actor.is_player then
        actor.inventory.strawberry_hearts = (actor.inventory.strawberry_hearts or 0) + 1
        worldscene:remove_actor(self)
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
