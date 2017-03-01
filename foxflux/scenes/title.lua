local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'
local tick = require 'vendor.tick'

local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'
local util = require 'klinklang.util'

local Menu = require 'foxflux.menu'

local TitleScene = BaseScene:extend{
    __tostring = function(self) return "titlescene" end,
}

function TitleScene:init(next_scene)
    TitleScene.__super.init(self)

    self.next_scene = next_scene

    self.music = love.audio.newSource('assets/music/title.ogg', 'stream')
    self.music:setLooping(true)

    self.image = love.graphics.newImage('assets/images/title.png')
    self.image:setFilter('linear', 'linear')

    self.is_menu_visible = false
    self.any_key_pressed = false

    self.save_files = game.detect_save_files()
    local choices = {}
    if #self.save_files > 0 then
        table.insert(choices, {
            label = "Continue",
            action = function() self:do_continue(self.save_files[1]) end,
        })
        table.insert(choices, {
            label = "New game",
            action = function()
                self.menu = self.confirm_menu
                self.menu.cursor = 1
            end,
        })

        self.confirm_menu = Menu{
            { label = "Just kidding!", action = function() self.menu = self.primary_menu end },
            { label = "Yeah, nuke it", action = function() self:do_new_game() end },
        }
    else
        table.insert(choices, { label = "New game", action = function() self:do_new_game() end })
    end
    table.insert(choices, { label = "Quit", action = function() love.event.quit() end })
    self.primary_menu = Menu(choices)
    self.menu = self.primary_menu
end

local pink = {255, 130, 206}
function TitleScene:do_continue(save_file)
    Gamestate.switch(SceneFader(self.next_scene, false, 1.0, pink, function()
        if save_file then
            game:load(save_file)
        end
        -- Set up autosave!
        -- FIXME this seems rather important to put in such an out of the way
        -- place, but it shouldn't go in love.load since we haven't loaded the
        -- existing save file yet
        tick.recur(function() game:save() end, 5)

        -- FIXME this doesn't even check if the file exists, which can give
        -- goofy errors later on
        local map = game.resource_manager:load(game.progress.last_map_path)
        self.next_scene:load_map(map, game.progress.last_map_spot)
    end))
end

function TitleScene:do_new_game()
    -- FIXME confirm
    game:erase_save()
    self:do_continue()
end


--------------------------------------------------------------------------------
-- hump.gamestate hooks

function TitleScene:enter()
    self.music:play()
end

function TitleScene:update(dt)
    -- Only load the first map if we've drawn at least one frame, to minimize
    -- the time spent showing the player nothing
    if not self.is_menu_visible then
        -- We do this here instead of in keypressed because otherwise, the
        -- keypress would be passed along to baton, and it'd get interpreted a
        -- second time in the menu itself!  Argh!  FIXME!
        if self.any_key_pressed then
            self.is_menu_visible = true
            self.any_key_pressed = false
        end
    else
        if game.input:pressed('menu') then
            self.is_menu_visible = false
            return
        end

        self.menu:update(dt)
        -- TODO this is somewhere that a repeat would be nice?
        if game.input:pressed('up') then
            self.menu:up()
        elseif game.input:pressed('down') then
            self.menu:down()
        elseif game.input:pressed('accept') then
            self.menu:accept()
        end
    end
end

function TitleScene:draw()
    local sw, sh = love.graphics.getDimensions()
    local iw, ih = self.image:getDimensions()
    local scale = math.max(sw / iw, sh / ih)

    love.graphics.draw(
        self.image,
        (sw - iw * scale) / 2,
        (sh - ih * scale) / 2,
        0,
        scale)

    if self.is_menu_visible then
        local w, h = love.graphics.getDimensions()
        self.menu:draw{
            x = w - 16,
            xalign = 'right',
            y = h - 16,
            yalign = 'bottom',
            margin = 16,
            bgcolor = {207, 60, 113, 128},
            shadowcolor = {207, 60, 113},
            textcolor = {255, 255, 255},
        }

        love.graphics.push('all')
        love.graphics.setColor(207, 60, 113, 128)
        local th = m5x7small:getHeight() * m5x7small:getLineHeight()
        love.graphics.rectangle('fill', 0, 0, w, th)
        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(m5x7small)
        love.graphics.printf("Strawberry Jam 2017 demo edition", 0, 0, w, 'center')
        love.graphics.pop()
    end
end

function TitleScene:keypressed(key, scancode, isrepeat)
    if isrepeat or util.any_modifier_keys() then
        return
    end

    if not self.is_menu_visible then
        self.any_key_pressed = true
    end
end

function TitleScene:gamepadpressed(joystick, button)
    if not self.is_menu_visible then
        self.any_key_pressed = true
    end
end


return TitleScene
