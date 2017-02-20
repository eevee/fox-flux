local Gamestate = require 'vendor.hump.gamestate'
local suit = require 'vendor.suit'

local BaseScene = require 'klinklang.scenes.base'
local util = require 'klinklang.util'

local DebugScene = BaseScene:extend{
    __tostring = function(self) return "pausescene" end,

    current_screen = 'main',
}

--------------------------------------------------------------------------------
-- various UI layouts

function DebugScene:init(font)
    DebugScene.__super.init(self)

    self.pause_state = { text = 'Stop time', checked = true }
    self.twiddle_states = {
        { _twiddle = 'show_blockmap', text = "Show blockmap" },
        { _twiddle = 'show_collision', text = "Show collisions" },
        { _twiddle = 'show_shapes', text = "Show all shapes" },
    }

    self.menu = 'main'
    self.main_submenu = 'WORLD'
    self.font = font or love.graphics.getFont()
    self.unit = self.font:getHeight() * self.font:getLineHeight()

    self.scrollbar_state = {value = 0, min = 0, max = 0}

    self.testable_voices = {}
    for path, fn in util.find_files{'assets/sounds/voicetest'} do
        table.insert(self.testable_voices, {
            path = path,
            filename = fn,
            sfx = game.resource_manager:load(path),
        })
    end
end

local function _suit_scrollable_area(layout, width, height, scrollbar_state, callback)
    -- FIXME this doesn't scissor, but it's not as simple as calling
    -- setScissor, because we're actually in update at the moment
    local padx, pady = layout:padding()

    local scrollbar_width = 8
    local inner_width = width - scrollbar_width - padx
    local x, y, w, h = layout:col(inner_width, height)
    local y0 = y + scrollbar_state.value
    layout:push(x, y0, w, h)

    callback(inner_width)

    local x, y = suit.layout:nextRow()
    layout:pop()
    scrollbar_state.min = math.min(0, height - (y - y0))
    -- TODO i would love to know if i don't need the scrollbar_state in advance, but...
    suit.Slider(scrollbar_state, {vertical = true}, suit.layout:col(scrollbar_width, nil))
end

function DebugScene:do_main_menu(dt)
    local margin = 8
    local padding = 8
    suit.layout:reset(margin, margin, padding)

    local width, height = love.graphics.getDimensions()
    width = width - margin * 2
    height = height - margin * 2

    -- Time control
    suit.layout:push(suit.layout:row(width, self.unit))
    suit.layout:padding(0)
    suit.Checkbox(self.pause_state, suit.layout:col(width / 4, self.unit))
    suit.Label("Advance by:", {align = 'right'}, suit.layout:col(width / 4))
    if suit.Button('frame', suit.layout:col(width / 8)).hit then
        self.wrapped:update(dt)
    end
    if suit.Button('1/200s', suit.layout:col(width / 8)).hit then
        self.wrapped:update(1/200)
    end
    if suit.Button('1/60s', suit.layout:col(width / 8)).hit then
        self.wrapped:update(1/60)
    end
    if suit.Button('1/2s', suit.layout:col(width / 8)).hit then
        self.wrapped:update(1/2)
    end
    suit.layout:pop()
    height = height - self.unit - padding

    -- Main tabs
    suit.layout:push(suit.layout:row(width, self.unit))
    local buttonct = 4
    local button_width = math.floor((width - padding * (buttonct - 1)) / buttonct)
    for _, submenu in ipairs{'WORLD', 'DIALOGUE'} do
        local opt = {}
        if submenu == self.main_submenu then
            opt.color = {
                normal = suit.theme.color.hovered,
                hovered = suit.theme.color.hovered,
                active = suit.theme.color.hovered,
            }
        end
        if suit.Button(submenu, opt, suit.layout:col(button_width, self.unit)).hit then
            self.main_submenu = submenu
            --self.scrollbar_state = {min = 0, value = 0}
        end
    end
    suit.layout:pop()
    height = height - self.unit - padding

    suit.layout:push(suit.layout:row(width, height))
    _suit_scrollable_area(suit.layout, width, height, self.scrollbar_state, function(inner_width)
        if self.main_submenu == 'WORLD' then
            self:do_world_menu(inner_width)
        elseif self.main_submenu == 'DIALOGUE' then
            self:do_dialogue_menu(inner_width)
        end
    end)
    suit.layout:pop()
end

function DebugScene:do_world_menu(inner_width)
    -- FIXME oughta save these settings somewhere
    -- FIXME and make command-line args for them?
    for _, state in ipairs(self.twiddle_states) do
        local checked = game.debug_twiddles[state._twiddle]
        state.checked = checked
        if suit.Checkbox(state, suit.layout:row(inner_width, self.unit)).hit then
            game.debug_twiddles[state._twiddle] = not checked
        end
    end
end

function DebugScene:do_dialogue_menu(inner_width)
    local dialogue_scene = self.wrapped
    if tostring(dialogue_scene) ~= "dialoguescene" then
        suit.Label('No dialogue found', suit.layout:row(inner_width, self.unit))
        return
    end

    suit.layout:push(suit.layout:row(inner_width, self.unit))
    suit.layout:padding(0)
    local bw = self.unit * 2
    local lw = inner_width - bw * 2
    if suit.Button("<", suit.layout:col(bw, self.unit)).hit then
        -- FIXME ok dialoguescene direly needs to have actual distinct
        -- functions for setting up "we are now at this point in this text"
        if dialogue_scene.script_index > 1 then
            dialogue_scene.script_index = dialogue_scene.script_index - 1
            dialogue_scene.curphrase = 1
            dialogue_scene.curline = 1
            dialogue_scene.curchar = 0
            dialogue_scene:_advance_script()
        end
    end
    suit.Label(
        ("On script step %d of %d"):format(dialogue_scene.script_index, #dialogue_scene.script),
        suit.layout:col(lw))
    if suit.Button(">", suit.layout:col(bw, self.unit)).hit then
        if dialogue_scene.script_index < #dialogue_scene.script then
            dialogue_scene.script_index = dialogue_scene.script_index + 1
            dialogue_scene.curphrase = 1
            dialogue_scene.curline = 1
            dialogue_scene.curchar = 0
            dialogue_scene:_advance_script()
        end
    end
    suit.layout:pop()

    -- TODO show current speaker, poses, etc., why not

    if #self.testable_voices > 0 then
        suit.Label("Change current speaker's voice to", suit.layout:row())
        for _, voice in ipairs(self.testable_voices) do
            if suit.Button(voice.filename, {id = voice}, suit.layout:row()).hit then
                dialogue_scene.phrase_speaker.chatter_sfx = voice.sfx
            end
        end
    end
end

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function DebugScene:enter(previous_scene)
    self.wrapped = previous_scene
    self._updated = false
end

function DebugScene:update(dt)
    -- FIXME stupid hack because the keypress that summons us, being from
    -- love.keypressed, is then also sent to us on the same tic, because i
    -- broke gamestate.  oops
    self._updated = true

    if not self.pause_state.checked then
        self.wrapped:update(dt)
    end

    love.graphics.push('all')
    love.graphics.setFont(self.font)
    if self.current_screen == 'main' then
        self:do_main_menu(dt)
    end
    love.graphics.pop()
end

function DebugScene:draw()
    self.wrapped:draw()

    love.graphics.push('all')
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.5 * 255)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(0, 255, 0)
    love.graphics.rectangle('line', 0.5, 0.5, w - 1, h - 1)
    love.graphics.rectangle('line', 1.5, 1.5, w - 3, h - 3)
    love.graphics.setColor(255, 255, 255)
    love.graphics.pop()

    love.graphics.push('all')
    love.graphics.setFont(self.font)
    suit.draw()
    love.graphics.pop()
end

function DebugScene:keypressed(key, scancode, isrepeat)
    if self._updated and (scancode == 'escape' or scancode == 'pause') and not love.keyboard.isScancodeDown('lctrl', 'rctrl', 'lalt', 'ralt', 'lgui', 'rgui') then
        Gamestate.pop()
    end
end


return DebugScene
