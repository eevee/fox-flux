local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Player = require 'klinklang.actors.player'
local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'


local Cerise = actors_base.Actor:extend{
    name = 'cerise',
    sprite_name = 'cerise',
    dialogue_position = 'right',
    dialogue_sprite_name = 'cerise portrait',

    is_usable = true,
}

function Cerise:on_use(activator)
    if not activator.is_player then
        return
    end

    Gamestate.push(DialogueScene({
        lexy = activator,
        cerise = self,
    }, {
        { "Hey, sweetie!", speaker = 'cerise' },
        { "Oh, hey.", speaker = 'lexy' },
    }))
end


return {
    Cerise = Cerise,
}
