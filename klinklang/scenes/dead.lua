local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'

local DeadScene = BaseScene:extend{
    __tostring = function(self) return "deadscene" end,

    wrapped = nil,
}

-- TODO it would be nice if i could formally eat keyboard input
function DeadScene:init(wrapped)
    BaseScene.init(self)

    self.wrapped = nil
end

function DeadScene:enter(previous_scene)
    self.wrapped = previous_scene
end

function DeadScene:update(dt)
    self.wrapped:update(dt)
end

function DeadScene:draw()
    self.wrapped:draw()

    love.graphics.push('all')
    local w, h = love.graphics.getDimensions()

    -- Draw a dark stripe across the middle of the screen for printing text on.
    -- We draw it twice, the first time slightly taller, so it has a slight
    -- fade on the top and bottom edges
    local bg_height = love.graphics.getHeight() / 4
    love.graphics.setColor(0, 0, 0, 128)
    love.graphics.rectangle('fill', 0, (h - bg_height) / 2, w, bg_height)
    love.graphics.rectangle('fill', 0, (h - bg_height) / 2 + 2, w, bg_height - 4)

    -- Give some helpful instructions
    -- FIXME this doesn't explain how to use the staff.  i kind of feel like
    -- that should be a ui hint in the background, anyway?  like attached to
    -- the inventory somehow.  maybe you even have to use it
    local line_height = m5x7:getHeight()
    local line1 = love.graphics.newText(m5x7, "you died")
    love.graphics.setColor(0, 0, 0)
    love.graphics.draw(line1, (w - line1:getWidth()) / 2, h / 2 - line_height * 1.5 + 1)
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(line1, (w - line1:getWidth()) / 2, h / 2 - line_height * 1.5)

    local line2 = love.graphics.newText(m5x7)
    line2:set{{255, 255, 255}, "press ", {52, 52, 52}, "R", {255, 255, 255}, " to restart"}
    local prefixlen = m5x7:getWidth("press ")
    local keylen = m5x7:getWidth("R")
    local quad = love.graphics.newQuad(384, 0, 32, 32, p8_spritesheet:getDimensions())
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(p8_spritesheet, quad, (w - line2:getWidth()) / 2 + prefixlen + keylen / 2 - 32 / 2, h / 2 - 32 / 2)
    love.graphics.draw(line2, (w - line2:getWidth()) / 2, h / 2 - line_height / 2)

    if worldscene.player.ptrs.savepoint then
        line2:set{{255, 255, 255}, "press ", {52, 52, 52}, "E", {255, 255, 255}, " to resurrect"}
        local keylen = m5x7:getWidth("E")
        local quad = love.graphics.newQuad(384, 0, 32, 32, p8_spritesheet:getDimensions())
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(p8_spritesheet, quad, (w - line2:getWidth()) / 2 + prefixlen + keylen / 2 - 32 / 2, h / 2 + line_height - 32 / 2)
        love.graphics.draw(line2, (w - line2:getWidth()) / 2, h / 2 + line_height / 2)
    end

    love.graphics.pop()
end

function DeadScene:keypressed(key, scancode, isrepeat)
    -- TODO really, this should load some kind of more formal saved game
    -- TODO also i question this choice of key
    if key == 'r' then
        Gamestate.switch(SceneFader(
            self.wrapped, true, 0.5, {0, 0, 0},
            function()
                self.wrapped:reload_map()
            end
        ))
    elseif key == 'e' then
        -- TODO this seems really invasive!
        -- FIXME hardcoded color, as usual
        local player = self.wrapped.player
        if player.ptrs.savepoint then
            game.resource_manager:get('assets/sounds/resurrect.ogg'):play()
            Gamestate.switch(SceneFader(
                self.wrapped, true, 0.25, {140, 214, 18},
                function()
                    -- TODO shouldn't this logic be in the staff or the savepoint somehow?
                    -- TODO eugh this magic constant
                    player:move_to(player.ptrs.savepoint.pos + Vector(0, 16))
                    player:resurrect()
                    -- TODO hm..  this will need doing anytime the player is forcibly moved
                    worldscene:update_camera()
                end))
        end
    end
end

return DeadScene
