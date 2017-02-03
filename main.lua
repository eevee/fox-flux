local utf8 = require 'utf8'

local Gamestate = require 'vendor.hump.gamestate'
local tick = require 'vendor.tick'

local ResourceManager = require 'klinklang.resources'
local WorldScene = require 'klinklang.scenes.world'
local SpriteSet = require 'klinklang.sprite'
local tiledmap = require 'klinklang.tiledmap'
local TitleScene = require 'isaacsdescent.scenes.title'


game = {
    VERSION = "0.1",
    TILE_SIZE = 32,

    progress = {
        flags = {},
    },

    debug = false,
    resource_manager = nil,
    -- FIXME this seems ugly, but the alternative is to have sprite.lua implicitly depend here
    sprites = SpriteSet._all_sprites,

    scale = 1,

    _determine_scale = function(self)
        -- Default resolution is 640 × 360, which is half of 720p and a third
        -- of 1080p and equal to 40 × 22.5 tiles.  With some padding, I get
        -- these as the max viewport size.
        local w, h = love.graphics.getDimensions()
        local MAX_WIDTH = 50 * 16
        local MAX_HEIGHT = 30 * 16
        self.scale = math.ceil(math.max(w / MAX_WIDTH, h / MAX_HEIGHT))
    end,

    getDimensions = function(self)
        return math.ceil(love.graphics.getWidth() / self.scale), math.ceil(love.graphics.getHeight() / self.scale)
    end,
}

local TILE_SIZE = 32


--------------------------------------------------------------------------------

function love.load(args)
    for i, arg in ipairs(args) do
        if arg == '--xyzzy' then
            print('Nothing happens.')
            game.debug = true
        end
    end

    love.graphics.setDefaultFilter('nearest', 'nearest', 1)

    -- Eagerly load all actor modules, so we can access them by name
    for _, package in ipairs{'klinklang', 'isaacsdescent'} do
        local dir = package .. '/actors'
        for _, filename in ipairs(love.filesystem.getDirectoryItems(dir)) do
            -- FIXME this should recurse, but i can't be assed right now
            if filename:match("%.lua$") and love.filesystem.isFile(dir .. '/' .. filename) then
                module = package .. '.actors.' .. filename:sub(1, #filename - 4)
                require(module)
            end
        end
    end

    local resource_manager = ResourceManager()
    resource_manager:register_default_loaders()
    resource_manager.locked = false  -- TODO make an api for this lol
    game.resource_manager = resource_manager

    -- Eagerly load all sound effects, which we will surely be needing
    local sounddir = 'assets/sounds'
    for _, filename in ipairs(love.filesystem.getDirectoryItems(sounddir)) do
        -- FIXME recurse?
        local path = sounddir .. '/' .. filename
        if love.filesystem.isFile(path) then
            resource_manager:load(path)
        end
    end

    -- Load all the graphics upfront
    -- FIXME the savepoint sparkle is wrong, because i have no way to specify
    -- where to loop back to
    dialogueboximg = love.graphics.newImage('assets/images/isaac-dialogue.png')
    dialogueboximg2 = love.graphics.newImage('assets/images/lexy-dialogue.png')
    -- FIXME evict this global
    p8_spritesheet = love.graphics.newImage('assets/images/spritesheet.png')

    for _, tspath in ipairs{
        'data/tilesets/pico8.tsx.json',
        'data/tilesets/player.tsx.json',
        'data/tilesets/portraits.tsx.json',
    } do
        local tileset = tiledmap.TiledTileset(tspath, nil, resource_manager)
        resource_manager:add(tspath, tileset)
    end

    -- FIXME probably want a way to specify fonts with named roles
    local fontscale = 2
    m5x7 = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * fontscale)
    --m5x7:setLineHeight(0.75)  -- TODO figure this out for sure
    love.graphics.setFont(m5x7)
    m5x7small = love.graphics.newFont('assets/fonts/m5x7.ttf', 16)

    love.joystick.loadGamepadMappings("vendor/gamecontrollerdb.txt")

    game.maps = {
        'pico8-01.tmx.json',
        'pico8-02.tmx.json',
        'pico8-03.tmx.json',
        'pico8-04.tmx.json',
        'pico8-05.tmx.json',
        'pico8-06.tmx.json',
        'pico8-07.tmx.json',
        'pico8-08.tmx.json',
        'pico8-09.tmx.json',
        'pico8-10.tmx.json',
        'pico8-11.tmx.json',
    }
    -- TODO should maps instead hardcode their next maps?  or should they just
    -- have a generic "exit" a la doom?
    game.map_index = 1
    --map = tiledmap.TiledMap("data/maps/" .. game.maps[game.map_index], resource_manager)
    --map = tiledmap.TiledMap("data/maps/slopetest.tmx.json", resource_manager)
    worldscene = WorldScene()

    Gamestate.registerEvents()
    --Gamestate.switch(worldscene)
    Gamestate.switch(TitleScene(worldscene, "data/maps/" .. game.maps[game.map_index]))

    --local tmpscene = DialogueScene(worldscene)
    --Gamestate.switch(tmpscene)
end

function love.update(dt)
    tick.update(dt)
end

function love.draw()
end

local _previous_size

function love.resize(w, h)
    game:_determine_scale()
end

function love.keypressed(key, scancode, isrepeat)
    if scancode == 'return' and not isrepeat and love.keyboard.isDown('lalt', 'ralt') then
        -- FIXME disabled until i can figure out how to scale this larger game
        do return end
        if love.window.getFullscreen() then
            love.window.setFullscreen(false)
            -- FIXME this freezes X for me until i ssh in and killall love, so.
            --love.window.setMode(_previous_size[1], _previous_size[2])
            -- This isn't called for resizes caused by code, but worldscene
            -- etc. sort of rely on knowing this
            love.resize(love.graphics.getDimensions())
        else
            -- LOVE claims to do this for me, but it lies
            _previous_size = {love.window.getMode()}
            love.window.setFullscreen(true)
        end
    end
end
