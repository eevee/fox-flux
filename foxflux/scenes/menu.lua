local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'

local MenuScene = BaseScene:extend{
    __tostring = function(self) return "menuscene" end,

    choices = {
        "Resume playing",
        -- TODO uhhhh yeah how do i...  do...  that
        "Abandon this room",
    },
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function MenuScene:enter(previous_scene)
    self.wrapped = previous_scene

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
    local y = math.floor((h - row_height * #game.progress.region_order) / 2)

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

    love.graphics.pop()
end

function MenuScene:keypressed(key, scancode, isrepeat)
    if (scancode == 'escape' or scancode == 'Menu') and not love.keyboard.isScancodeDown('lctrl', 'rctrl', 'lalt', 'ralt', 'lgui', 'rgui') then
        Gamestate.pop()
    end
end


return MenuScene
