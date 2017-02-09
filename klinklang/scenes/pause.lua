local Gamestate = require 'vendor.hump.gamestate'
local suit = require 'vendor.suit'

local BaseScene = require 'klinklang.scenes.base'

local PauseScene = BaseScene:extend{
    __tostring = function(self) return "pausescene" end,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function PauseScene:init()
    self.twiddle_states = {
        { _twiddle = 'show_blockmap', text = "Show blockmap" },
        { _twiddle = 'show_collision', text = "Show collisions" },
        { _twiddle = 'show_shapes', text = "Show all shapes" },
    }
end

function PauseScene:enter(previous_scene)
    self.wrapped = previous_scene
end

function PauseScene:update(dt)
    -- FIXME maybe this should be split into menu (esc) vs debug (pause).  what would pause do in non-debug mode?
    -- FIXME oughta save these settings somewhere
    if not game.debug then
        return
    end

    suit.layout:reset(32, 32)
    suit.layout:padding(16, 16)

    suit.Button('Whats up', suit.layout:row(300, 30))
    for _, state in ipairs(self.twiddle_states) do
        local checked = game.debug_twiddles[state._twiddle]
        state.checked = checked
        if suit.Checkbox(state, suit.layout:row()).hit then
            game.debug_twiddles[state._twiddle] = not checked
        end
    end

end

function PauseScene:draw()
    self.wrapped:draw()

    love.graphics.push('all')
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.5 * 255)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf('* p a u s e d *', 8, 8, w - 8 * 2, 'center')
    love.graphics.pop()

    if game.debug then
        suit.draw()
    end
end

function PauseScene:keypressed(key, scancode, isrepeat)
    if (scancode == 'escape' or scancode == 'pause') and not love.keyboard.isScancodeDown('lctrl', 'rctrl', 'lalt', 'ralt', 'lgui', 'rgui') then
        Gamestate.pop()
    end
end


return PauseScene
