local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Player = require 'klinklang.actors.player'
local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'

local BossScene = require 'foxflux.scenes.boss'
local conversations = require 'foxflux.conversations'


local Dart = actors_base.MobileActor:extend{
    name = 'dart',
    sprite_name = 'dart',
    is_usable = true,
}

function Dart:init(...)
    Dart.__super.init(self, ...)

    self.velocity = Vector(-256, 0)
    self.sprite:set_facing_right(false)
end

function Dart:on_use(activator)
    local convo = conversations.pick_conversation('examine dart', activator.form)
    Gamestate.push(DialogueScene({ lexy = activator }, convo))
end

function Dart:blocks()
    return false
end

function Dart:on_collide_with(actor, ...)
    if actor then
        return true
    end

    self.velocity = Vector()
    return Dart.__super.on_collide_with(self, actor, ...)
end

function Dart:nudge(movement, pushers)
    return Dart.__super.nudge(self, movement, pushers, true)
end

function Dart:update(dt)
    Dart.__super.update(self, dt)

    local vx = math.abs(self.velocity.x)
    local vy = math.abs(self.velocity.y)
    if vx > vy * 2 then
        self.sprite:set_pose('forwards')
    elseif vy > vx * 2 then
        self.sprite:set_pose('down')
    else
        self.sprite:set_pose('falling')
    end
end


local Lop = actors_base.Actor:extend{
    name = 'lop',
    sprite_name = 'lop',
    z = 1,  -- in front of dart
    dialogue_position = 'right',
    dialogue_chatter_sound = 'assets/sounds/chatter-lop.ogg',
    dialogue_background = 'assets/images/dialoguebox-lop.png',
    dialogue_color = {35, 23, 18},
    dialogue_shadow = {123, 123, 123},
    dialogue_sprites = {
        { name = 'base', sprite_name = 'lop portrait', while_talking = { default = 'talking' } },
        { name = 'eyes', sprite_name = 'lop portrait - eye' },
        { name = 'decor', sprite_name = 'lop portrait - decor', default = false },
    },

    is_usable = true,

    is_defeated = false,
}

function Lop:on_enter()
    Lop.__super.on_enter(self)

    self.sprite:set_facing_right(false)
    if game:flag('confronted lop') then
        self.is_defeated = true
        self.sprite:set_pose('stand')
        self:schedule_idle()
    else
        self.sprite:set_pose('armed')
    end
end

function Lop:on_approach_lop(activator)
    if not self.is_defeated then
        Gamestate.push(BossScene(activator, self))
        game:set_flag('confronted lop')
    end
end

function Lop:launch_dart(scene)
    worldscene.tick:delay(function()
        local dart = Dart(self.pos + Vector(-34, -79))
        worldscene:add_actor(dart)
        self.sprite:set_pose('out of ammo')
    end, 1)
    :after(function()
        self.sprite:set_pose('disarmed', function()
            self.is_defeated = true
            self.sprite:set_pose('stand')
            self:schedule_idle()
            scene:announce_victory()
        end)
    end, 2)
end

function Lop:schedule_idle()
    worldscene.tick:delay(function()
        if math.random() < 0.5 then
            self.sprite:set_pose('wag')
        else
            self.sprite:set_pose('pant')
        end
    end, util.random_float(1, 3))
    :after(function()
        self.sprite:set_pose('stand')
        self:schedule_idle()
    end, util.random_float(2, 5))
end

function Lop:on_use(activator)
    if not activator.is_player then
        return
    end

    local convo
    if game:flag('has forest passcode') then
        convo = conversations.pick_conversation('lop followup', activator.form)
    else
        convo = conversations.pick_conversation('defeat lop', activator.form)
    end
    Gamestate.push(DialogueScene({
        lexy = activator,
        lop = self,
    }, convo))
end


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
        ['not villain'] = { disguise = false, eyelids = false },
        smiling = { eyes = 'smiling' },
        neutral = { eyes = 'default' },
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
