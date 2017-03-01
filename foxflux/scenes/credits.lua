local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'
local util = require 'klinklang.util'

local CreditsScene = BaseScene:extend{
    __tostring = function(self) return "creditsscene" end,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function CreditsScene:init()
    CreditsScene.__super.init(self)

    self.music = love.audio.newSource('assets/music/credits.ogg', 'stream')
    self.music:setLooping(true)

    self.lop_sprite = game.sprites['lop']:instantiate()
    self.lop_sprite:set_pose('armed')
    self.lop_sprite:update(0)
    self.lexy_sprite = game.sprites['lexy: rubber']:instantiate()
    self.lexy_sprite:set_pose('walk')
    self.lexy_sprite:update(0)
    self.cerise_sprite = game.sprites['cerise']:instantiate()
    self.cerise_sprite:set_pose('disguise')
    self.cerise_sprite:set_facing_right(false)
    self.cerise_sprite:update(0)

    self.pointer_cursor = love.mouse.getSystemCursor('hand')
    self.hotspot = nil
    self:_lay_out_text()
end

function CreditsScene:update(dt)
    self.music:play()
    self.lexy_sprite:update(dt)
end

function CreditsScene:_lay_out_text()
    local texts = {
        {"fox flux ~ for Strawberry Jam 2017"},
        {{"itch.io", "https://eevee.itch.io/fox-flux"}, " ~ ", {"source code + more credits", "https://github.com/eevee/fox-flux"}},
        {"Made by ", {"Eevee", "https://eev.ee/"}, " (", {"@eevee", "https://twitter.com/eevee"}, ")"},
        {" "},
        {"Thanks to ", {"glip", "http://glitchedpuppet.com/"}, " for the music,"},
        {"art advice, Lop sprite, and ", {"Flora universe", "http://floraverse.com/"}, "!"},
        {" "},
        {"Thanks for playing!  More coming eventually!"},
    }

    local font = love.graphics.getFont()
    local w, h = game:getDimensions()
    self.text_layout = {}
    local y = 0
    for i, line in ipairs(texts) do
        local layout = {}
        self.text_layout[i] = layout
        local line_width = 0
        local line_height = 0
        for j, chunk in ipairs(line) do
            local s, url
            if type(chunk) == 'string' then
                s = chunk
            else
                s, url = unpack(chunk)
            end

            local text = love.graphics.newText(font, s)
            local tw, th = text:getDimensions()
            table.insert(layout, {
                text = text,
                width = tw,
                height = th,
                url = url,
                dx = line_width,
            })

            line_width = line_width + tw
            line_height = math.max(line_height, th)
        end
        layout.width = line_width
        layout.y = y
        y = y + line_height
    end

    self.hotspots = {}
    for _, row in ipairs(self.text_layout) do
        row.x = math.floor((w - row.width) / 2)
        for _, cell in ipairs(row) do
            cell.x = row.x + cell.dx
            cell.y = row.y
            if cell.url then
                table.insert(self.hotspots, {
                    cell.x, cell.y, cell.x + cell.width, cell.y + cell.height,
                    url = cell.url,
                })
            end
        end
    end
end

function CreditsScene:draw()
    love.graphics.push('all')
    love.graphics.scale(game.scale, game.scale)
    local w, h = game:getDimensions()
    love.graphics.setColor(255, 130, 206)
    love.graphics.rectangle('fill', 0, 0, w, h)

    love.graphics.setColor(255, 255, 255)
    local font = love.graphics.getFont()
    local th = font:getHeight() * font:getLineHeight()

    for _, row in ipairs(self.text_layout) do
        for _, cell in ipairs(row) do
            if cell.url then
                love.graphics.setColor(135, 22, 70)
            else
                love.graphics.setColor(255, 255, 255)
            end
            love.graphics.draw(cell.text, cell.x, cell.y)
        end
    end

    local margin = 8
    local cellw = 96
    local cellh = 128
    self.lop_sprite:draw_at(Vector(margin + cellw / 2, h - margin))
    self.lexy_sprite:draw_at(Vector(margin + cellw + cellw / 2, h - margin))
    self.cerise_sprite:draw_at(Vector(w - margin - cellw / 2, h - margin))

    love.graphics.pop()
end

function CreditsScene:resize()
    self:_lay_out_text()
end

function CreditsScene:_check_hotspot(x, y)
    x = x / game.scale
    y = y / game.scale
    local old_hotspot = self.hotspot

    self.hotspot = nil
    for _, spot in ipairs(self.hotspots) do
        local x0, y0, x1, y1 = unpack(spot)
        if x0 <= x and x <= x1 and y0 <= y and y <= y1 then
            self.hotspot = spot
            break
        end
    end

    if old_hotspot and not self.hotspot then
        love.mouse.setCursor()
    elseif not old_hotspot and self.hotspot then
        love.mouse.setCursor(self.pointer_cursor)
    end
end

function CreditsScene:mousemoved(x, y, dx, dy, istouch)
    self:_check_hotspot(x, y)
end

function CreditsScene:focus()
    self:_check_hotspot(love.mouse.getX(), love.mouse.getY())
end

function CreditsScene:mousepressed(x, y, button, istouch)
    if button == 1 and self.hotspot then
        love.system.openURL(self.hotspot.url)
    end
end

return CreditsScene
