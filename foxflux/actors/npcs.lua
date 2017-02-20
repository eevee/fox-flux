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
    dialogue_chatter_sound = 'assets/sounds/chatter-cerise.ogg',
    dialogue_background = 'assets/images/dialoguebox-cerise.png',
    dialogue_color = {135, 22, 70},
    dialogue_shadow = {207, 60, 113, 128},
    dialogue_sprites = {
        { name = 'base', sprite_name = 'cerise portrait - base' },
        { name = 'eyes', sprite_name = 'cerise portrait - eyes' },
        { name = 'snoot', sprite_name = 'cerise portrait - snoot', while_talking = { default = 'talking' } },
        { name = 'hand', sprite_name = 'cerise portrait - far hand', default = false },
        { name = 'eyelids', sprite_name = 'cerise portrait - eyelids', default = false },
        { name = 'disguise', sprite_name = 'cerise portrait - disguise', default = false },
        compact = { hand = 'compact' },
        villain = { disguise = 'panties', eyelids = 'furrowed brow' },
    },

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
