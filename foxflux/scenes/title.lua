local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'
local util = require 'klinklang.util'

local TitleScene = BaseScene:extend{
    __tostring = function(self) return "titlescene" end,
}

function TitleScene:init(next_scene, map_path)
    TitleScene.__super.init(self)

    self.music = love.audio.newSource('assets/music/title.ogg', 'stream')
    self.music:setLooping(true)

    self.image = love.graphics.newImage('assets/images/title.png')
    self.image:setFilter('linear', 'linear')

    self.next_scene = next_scene
    self.map_path = map_path

    -- waiting => loading => title <=> menu
    self.state = 'waiting'
    self.any_key_pressed = false

    self.menu_choices = {}
    if game.has_savegame then
        table.insert(self.menu_choices,
            { label = "Continue", action = function() self:do_continue() end })
    end
    table.insert(self.menu_choices, { label = "New game", action = function() self:do_new_game() end })
    table.insert(self.menu_choices, { label = "Quit", action = function() love.event.quit() end })
    self.menu_cursor = 1
    self.menu_cursor_sprite = game.sprites['menu cursor']:instantiate()

    self.menu_width = 0
    self.menu_height = 0
    for _, choice in ipairs(self.menu_choices) do
        choice.text = love.graphics.newText(m5x7, choice.label)
        choice.text_width = choice.text:getWidth()
        self.menu_width = math.max(self.menu_width, choice.text_width)
        self.menu_height = self.menu_height + choice.text:getHeight()
    end
end

local pink = {255, 130, 206}
function TitleScene:do_continue()
    Gamestate.switch(SceneFader(self.next_scene, false, 1.0, pink))
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
    if self.state == 'loading' then
        local map = game.resource_manager:load(self.map_path)
        self.next_scene:load_map(map)
        self.state = 'title'
    elseif self.state == 'title' then
        -- We do this here instead of in keypressed because otherwise, the
        -- keypress would be passed along to baton, and it'd get interpreted a
        -- second time in the menu itself!  Argh!  FIXME!
        if self.any_key_pressed then
            self.state = 'menu'
            self.any_key_pressed = false
        end
    elseif self.state == 'menu' then
        if game.input:pressed('menu') then
            self.state = 'title'
            return
        end
        -- TODO this is somewhere that a repeat would be nice?
        if game.input:pressed('up') then
            self.menu_cursor = self.menu_cursor - 1
            if self.menu_cursor <= 0 then
                self.menu_cursor = #self.menu_choices
            end
        elseif game.input:pressed('down') then
            self.menu_cursor = self.menu_cursor + 1
            if self.menu_cursor > #self.menu_choices then
                self.menu_cursor = 1
            end
        elseif game.input:pressed('accept') then
            self.menu_choices[self.menu_cursor].action()
        end
    end
end

function TitleScene:draw()
    if self.state == 'waiting' then
        self.state = 'loading'
    end

    local sw, sh = love.graphics.getDimensions()
    local iw, ih = self.image:getDimensions()
    local scale = math.max(sw / iw, sh / ih)

    love.graphics.draw(
        self.image,
        (sw - iw * scale) / 2,
        (sh - ih * scale) / 2,
        0,
        scale)


    if self.state == 'menu' then
        self:_draw_menu()
    end
end

local deep_pink = {207, 60, 113}
function TitleScene:_draw_menu()
    love.graphics.push('all')
    local w, h = love.graphics.getDimensions()
    local margin = 16

    love.graphics.setColor(207, 60, 113, 128)  -- deep_pink + 50% alpha
    local mw = self.menu_width + margin * 2 + 16
    local mh = self.menu_height + margin * 2
    love.graphics.rectangle('fill', w - margin - mw, h - margin - mh, mw, mh)

    local x = w - margin * 2 - self.menu_width
    local y = h - margin * 2 - self.menu_height
    for i, choice in ipairs(self.menu_choices) do
        love.graphics.setColor(deep_pink)
        love.graphics.draw(choice.text, x, y + 2)
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(choice.text, x, y)
        local th = choice.text:getHeight()
        if i == self.menu_cursor then
            self.menu_cursor_sprite:draw_at(Vector(x - 16, y + th / 2))
        end
        y = y + th
    end
    love.graphics.pop()
end

function TitleScene:keypressed(key, scancode, isrepeat)
    if isrepeat or util.any_modifier_keys() then
        return
    end

    if self.state == 'title' then
        self.any_key_pressed = true
    end
end

function TitleScene:gamepadpressed(joystick, button)
    if self.state == 'title' then
        self.any_key_pressed = true
    end
end


return TitleScene
