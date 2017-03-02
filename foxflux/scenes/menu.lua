local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'
local util = require 'klinklang.util'

local Menu = require 'foxflux.menu'

local MenuScene = BaseScene:extend{
    __tostring = function(self) return "menuscene" end,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function MenuScene:enter(previous_scene)
    self.wrapped = previous_scene
    if self.wrapped.music then
        self.wrapped.music:pause()
    end

    self.hearts_by_region = {}
    self.hearts_total = 0
    for region, map_hearts in pairs(game.progress.hearts) do
        local heartct = 0
        for map_path, hearts in pairs(map_hearts) do
            for heart, collected in pairs(hearts) do
                if collected then
                    heartct = heartct + 1
                end
            end
        end
        self.hearts_by_region[region] = heartct
        self.hearts_total = self.hearts_total + heartct
    end

    local choices = {
        {
            label = "Resume playing",
            action = function() self:_close_menu() end,
        },
    }
    local overworld_map = worldscene.map:prop('overworld map')
    if overworld_map then
        local overworld_spot = worldscene.map:prop('overworld spot')
        table.insert(choices, {
            label = "Leave this area",
            action = function()
                Gamestate.switch(SceneFader(worldscene, true, 0.33, {255, 130, 206}, function()
                    worldscene:load_map(game.resource_manager:load(overworld_map), overworld_spot)
                    -- FIXME really this should be a general "reset actor" thing
                    worldscene.player:transform('rubber')
                end))
            end,
        })
    end
    table.insert(choices, { label = "Quit game", action = function() love.event.quit() end })
    self.menu = Menu(choices)

    self.first_frame = true
end

function MenuScene:update(dt)
    -- TODO SIIIGGHHH this would be fixed if gamestates only switched between frames i think
    if game.input:pressed('menu') and not util.any_modifier_keys() and not self.first_frame then
        self:_close_menu()
        return
    end
    self.first_frame = false

    self.menu:update(dt)
    if game.input:pressed('up') then
        self.menu:up()
    elseif game.input:pressed('down') then
        self.menu:down()
    elseif game.input:pressed('accept') and not util.any_modifier_keys() then
        self.menu:accept()
    end
end

function MenuScene:draw()
    self.wrapped:draw()

    love.graphics.push('all')
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.5 * 255)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(255, 255, 255)

    -- TODO i wonder if suit.layout could help with this, or if there's a more
    -- powerful layout engine somewhere, or if i should write my own since i do
    -- this sort of simple thing a lot and the math is noisy
    local hearts_table = {}
    local sprite = game.sprites['heart counter']:instantiate()
    local region_width = 192
    local icon_width = 32
    local count_width = 64
    local row_width = region_width + icon_width + count_width
    local x = math.floor((w - row_width) / 2)
    local font = love.graphics.getFont()
    local row_height = font:getHeight() * font:getLineHeight()
    local y = math.floor(h * 2/3 - (row_height * #game.progress.region_order) / 2)

    -- TODO this hardcodes the total number of hearts, but...  eh...
    love.graphics.printf(
        ("Completion rate: %.4g%%"):format(self.hearts_total / 200 * 100),
        x, y, row_width, 'center')
    for _, region in ipairs(game.progress.region_order) do
        y = y + row_height
        love.graphics.printf(region, x, y, region_width, 'left')
        sprite:draw_anchorless(Vector(x + region_width, y))
        love.graphics.printf(
            ("%d"):format(self.hearts_by_region[region] or 0),
            x + region_width + icon_width, y, count_width, 'right')
    end

    self.menu:draw{
        x = w / 2,
        y = h / 3,
        xalign = 'center',
        yalign = 'middle',
    }

    love.graphics.pop()
end

function MenuScene:_close_menu()
    if self.wrapped.music then
        self.wrapped.music:resume()
    end
    Gamestate.pop()
end


return MenuScene
