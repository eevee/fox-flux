local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'
local flux = require 'vendor.flux'
local tick = require 'vendor.tick'

local BaseScene = require 'klinklang.scenes.base'

local BossScene = BaseScene:extend{
    __tostring = function(self) return "bossscene" end,
}

function BossScene:init(player, boss)
    BossScene.__super.init(self)

    self.player = player
    self.boss = boss

    self.flux = flux.group()
    self.tick = tick.group()
    self.font = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * 4)
    self.overlay_opacity = 0
    self.healthbar_width = 0
    self.state = 'camera'
end

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function BossScene:enter(previous_scene)
    self.wrapped = previous_scene

    self.player.is_locked = true
    self.player:decide_walk(0)
    self.player:decide_abandon_jump()
    self.player:decide_climb(nil)
    self.player.velocity = Vector()
    self.player.sprite:set_pose('stand')
    self.player.sprite:set_facing_right(true)

    local x0, y0, x1, y1 = self.boss.shape:bbox()
    local w, h = game:getDimensions()
    local goal = x1 + 64 - w

    -- Move the camera to show Lop
    self.flux:to(self.wrapped.camera, 2, { x = goal })
    :oncomplete(function() self.state = 'warning' end)
    :after(self, 0.5, { overlay_opacity = 1 })
    :after(self, 0.5, { overlay_opacity = 0 }):ease('quadin')
    :after(self, 0.5, { overlay_opacity = 1 })
    :after(self, 0.5, { overlay_opacity = 0 }):ease('quadin')
    :after(self, 0.5, { overlay_opacity = 1 })
    :after(self, 0.5, { overlay_opacity = 0 }):ease('quadin')
    :oncomplete(function() self.state = 'hp' end)
    :after(self, 2, { healthbar_width = 1 }):ease('linear')
    :oncomplete(function()
        self.boss:launch_dart(self)
    end)
end

function BossScene:announce_victory()
    self.state = 'victory'
    self.flux:to(self, 0.5, { overlay_opacity = 1 }):delay(1)
    :oncomplete(function() self.state = 'victory2' end)
    :after(self, 0.5, { overlay_opacity = 0 }):ease('quadin'):delay(1)
    :oncomplete(function()
        self.player.is_locked = false
        Gamestate.pop()
    end)
end

function BossScene:update(dt)
    self.flux:update(dt)
    self.tick:update(dt)
    self.wrapped:update(dt)
end

function BossScene:draw()
    self.wrapped:draw()

    love.graphics.push('all')
    love.graphics.scale(game.scale, game.scale)
    local w, h = game:getDimensions()
    if self.state == 'warning' then
        love.graphics.setColor(128, 0, 0, self.overlay_opacity * 0.75 * 255)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(255, 255, 255, self.overlay_opacity * 255)
        love.graphics.setFont(self.font)
        love.graphics.printf('W A R N I N G', 8, (h - self.font:getHeight()) / 2, w - 8 * 2, 'center')
    end
    if self.state == 'hp' or self.state == 'victory' then
        local width = math.ceil((w - 16) * self.healthbar_width)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle('fill', 8 + 0.5, h - 8 - 16 + 0.5, width, 16)
        love.graphics.setColor(255, 0, 0)
        love.graphics.rectangle('fill', 8 + 1.5, h - 8 - 16 + 1.5, width - 2, 16 - 2)
    end
    if self.state == 'victory' or self.state == 'victory2' then
        love.graphics.setColor(0, 128, 32, self.overlay_opacity * 0.75 * 255)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(255, 255, 255, self.overlay_opacity * 255)
        love.graphics.setFont(self.font)
        local tw = w - 8 * 2
        local x = 8
        if self.state == 'victory' then
            x = x - tw * (1 - self.overlay_opacity)
        else
            x = x + tw * (1 - self.overlay_opacity)
        end
        love.graphics.printf('V I C T O R Y', x, (h - self.font:getHeight()) / 2, w - 8 * 2, 'center')
    end
    love.graphics.pop()
end


return BossScene
