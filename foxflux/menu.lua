-- FIXME this would be pretty handy if it were finished and fleshed out!
local Vector = require 'vendor.hump.vector'

local Object = require 'klinklang.object'

local Menu = Object:extend{}

function Menu:init(choices)
    self.choices = choices
    self.cursor = 1
    self.cursor_sprite = game.sprites['menu cursor']:instantiate()

    self.width = 0
    self.height = 0
    for _, choice in ipairs(self.choices) do
        choice.text = love.graphics.newText(m5x7, choice.label)
        choice.text_width = choice.text:getWidth()
        self.width = math.max(self.width, choice.text_width)
        self.height = self.height + choice.text:getHeight()
    end
end

function Menu:update(dt)
    self.cursor_sprite:update(dt)
end

-- TODO would these args make more sense as constructor args, or
function Menu:draw(args)
    local anchorx = math.floor(args.x)
    local anchory = math.floor(args.y)
    local xalign = args.xalign or 'center'
    local yalign = args.yalign or 'top'
    local margin = args.margin or 0
    local marginx = args.marginx or margin
    local marginy = args.marginy or margin
    local bgcolor = args.bgcolor
    local shadowcolor = args.shadowcolor
    local textcolor = args.textcolor or {255, 255, 255}

    -- FIXME hardcoded, bleh
    local cursor_width = 16

    local w, h = love.graphics.getDimensions()
    local mw = self.width + marginx * 2 + cursor_width
    local mh = self.height + marginy * 2
    local x = anchorx
    if xalign == 'center' then
        x = x - math.ceil(mw / 2)
    elseif xalign == 'right' then
        x = x - mw
    end
    local y = anchory
    if yalign == 'middle' then
        y = y - math.ceil(mh / 2)
    elseif yalign == 'bottom' then
        y = y - mh
    end

    love.graphics.push('all')

    if bgcolor then
        love.graphics.setColor(bgcolor)
        love.graphics.rectangle('fill', x, y, mw, mh)
    end

    x = x + marginx + cursor_width
    y = y + marginy
    for i, choice in ipairs(self.choices) do
        if shadowcolor then
            love.graphics.setColor(shadowcolor)
            love.graphics.draw(choice.text, x, y + 2)
        end
        love.graphics.setColor(textcolor)
        love.graphics.draw(choice.text, x, y)
        local th = choice.text:getHeight()
        if i == self.cursor then
            self.cursor_sprite:draw_at(Vector(x - cursor_width, y + th / 2))
        end
        y = y + th
    end
    love.graphics.pop()
end

-- API

function Menu:up()
    self.cursor = self.cursor - 1
    if self.cursor <= 0 then
        self.cursor = #self.choices
    end
end

function Menu:down()
    self.cursor = self.cursor + 1
    if self.cursor > #self.choices then
        self.cursor = 1
    end
end

function Menu:accept()
    self.choices[self.cursor].action()
end


return Menu
