local utf8 = require 'utf8'

local baton = require 'vendor.baton'
local json = require 'vendor.dkjson'
local Gamestate = require 'vendor.hump.gamestate'
local tick = require 'vendor.tick'

local ResourceManager = require 'klinklang.resources'
local DebugScene = require 'klinklang.scenes.debug'
local WorldScene = require 'klinklang.scenes.world'
local SpriteSet = require 'klinklang.sprite'
local tiledmap = require 'klinklang.tiledmap'
local util = require 'klinklang.util'

local TitleScene = require 'foxflux.scenes.title'


game = {
    VERSION = "0.1",
    TILE_SIZE = 32,

    input = nil,

    progress = {
        flags = {},
        topics = {},
        hearts = {},  -- region => map path => heart id => bool
        -- TODO hmm, this avoids "knowing" the progression, which is nice in
        -- theory, but also feels a wee bit hokey
        region_order = {},
    },
    save_files = {},
    is_dirty = false,

    -- FIXME it nearly goes without saying by now, but this should be in its
    -- own file and be a real object.  in fact progress should also be its own
    -- type, and these should be methods on /it/
    flag = function(self, flag)
        return self.progress.flags[flag]
    end,
    set_flag = function(self, flag)
        self.is_dirty = true
        self.progress.flags[flag] = true
    end,
    update_heart_list = function(self, map, heart_list)
        local region = map:prop('region', '')
        if not self.progress.hearts[region] then
            self.progress.hearts[region] = {}
            table.insert(self.progress.region_order, region)
        end
        local old = self.progress.hearts[region][map.path] or {}
        local new = {}
        for _, heart in ipairs(heart_list) do
            new[heart] = old[heart] or false
        end
        self.progress.hearts[region][map.path] = new
    end,
    -- TODO should be able to get map from heart?
    heart = function(self, map, heart)
        local region = map:prop('region', '')
        return self.progress.hearts[region]
            and self.progress.hearts[region][map.path]
            and self.progress.hearts[region][map.path][heart]
    end,
    set_heart = function(self, map, heart)
        local region = map:prop('region', '')
        -- These two cases shouldn't actually happen, but...
        if not self.progress.hearts[region] then
            self.progress.hearts[region] = {}
        end
        if not self.progress.hearts[region][map.path] then
            self.progress.hearts[region][map.path] = {}
        end
        if self.progress.hearts[region][map.path][heart] then
            return
        end

        self.is_dirty = true
        self.progress.hearts[region][map.path][heart] = true
    end,

    save = function(self)
        if self.is_dirty then
            self:really_save()
        end
    end,
    really_save = function(self)
        love.filesystem.write('demosave.json', json.encode(self.progress))
        self.is_dirty = false
    end,
    load = function(self)
        local data = love.filesystem.read('demosave.json')
        if data then
            local savegame, _pos, err = json.decode(data)
            if not savegame then
                print("Error loading save file:", err)
                local fn = ("demosave-broken-%d.json"):format(os.time())
                love.filesystem.write(fn, data)
                love.filesystem.remove('demosave.json')
                print(("Starting a new game, but backing up old save file as %s"):format(fn))
            else
                self.has_savegame = true
                for k, v in pairs(savegame) do
                    game.progress[k] = v
                end
            end
        end
    end,
    erase_save = function(self)
        love.filesystem.remove('demosave.json')
        -- TODO this seems very silly; maybe i just shouldn't load the save until the title screen actually tries to continue?  i need to use that to figure out the last place i went, too
        self.progress = {
            flags = {},
            topics = {},
            hearts = {},  -- region => map path => heart id => bool
            region_order = {},
        }
    end,

    debug = false,
    debug_twiddles = {
        show_blockmap = true,
        show_collision = true,
        show_shapes = true,
    },
    debug_hits = {},
    resource_manager = nil,
    -- FIXME this seems ugly, but the alternative is to have sprite.lua implicitly depend here
    sprites = SpriteSet._all_sprites,

    scale = 1,

    _determine_scale = function(self)
        -- Default resolution is 640 × 360, which is half of 720p and a third
        -- of 1080p and equal to 40 × 22.5 tiles.  With some padding, I get
        -- these as the max viewport size.
        -- TODO this doesn't specify any /minimum/ size...  but it could
        local w, h = love.graphics.getDimensions()
        local MAX_WIDTH = 50 * 16  -- 800
        local MAX_HEIGHT = 30 * 16  -- 480
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
    for path in util.find_files{'klinklang/actors', 'foxflux/actors', pattern = '%.lua$'} do
        module = path:sub(1, #path - 4):gsub('/', '.')
        require(module)
    end

    local resource_manager = ResourceManager()
    resource_manager:register_default_loaders()
    resource_manager:register_loader('tmx.json', function(path)
        return tiledmap.TiledMap(path, resource_manager)
    end)
    resource_manager.locked = false  -- TODO make an api for this lol
    game.resource_manager = resource_manager

    -- Eagerly load all sound effects, which we will surely be needing
    for path in util.find_files{'assets/sounds'} do
        resource_manager:load(path)
    end

    -- Load all the graphics upfront
    for path in util.find_files{'data/tilesets', pattern = "%.tsx%.json$"} do
        local tileset = tiledmap.TiledTileset(path, nil, resource_manager)
        resource_manager:add(path, tileset)
    end

    -- FIXME probably want a way to specify fonts with named roles
    local fontscale = 2
    m5x7 = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * fontscale)
    --m5x7:setLineHeight(0.75)  -- TODO figure this out for sure
    love.graphics.setFont(m5x7)
    m5x7small = love.graphics.newFont('assets/fonts/m5x7.ttf', 16)

    love.joystick.loadGamepadMappings("vendor/gamecontrollerdb.txt")

    game:load()
    tick.recur(function() game:save() end, 5)

    -- FIXME things i would like to have here:
    -- - cleverly scale axis inputs like that other thing, and limit them to a circular range as well?
    -- - use scancodes by default!!!  the examples use keys
    -- - get the most appropriate control for an input (first matching current device type)
    -- - mutually exclusive controls
    -- - distinguish between edge-flip and receiving an actual event
    -- - aliases or something?  so i can say "accept" means "use", or even "either use or jump"
    -- - take repeats into account?
    game.input = baton.new{
        left = {'key:left', 'axis:leftx-', 'button:dpleft'},
        right = {'key:right', 'axis:leftx+', 'button:dpright'},
        up = {'key:up', 'axis:lefty-', 'button:dpup'},
        down = {'key:down', 'axis:lefty+', 'button:dpdown'},
        jump = {'key:space', 'button:a'},
        use = {'sc:e', 'button:x'},

        -- TODO what should the guide button do?
        menu = {'sc:escape', 'button:start'},
        accept = {'sc:e', 'sc:space', 'sc:return', 'button:a'},
    }

    game.maps = {
        'forest-overworld.tmx.json',
        'playground.tmx.json',
    }
    -- TODO should maps instead hardcode their next maps?  or should they just
    -- have a generic "exit" a la doom?
    game.map_index = 1
    --local map = resource_manager:load("data/maps/" .. game.maps[game.map_index])
    worldscene = WorldScene()
    --worldscene:load_map(map)

    Gamestate.registerEvents()
    --Gamestate.switch(worldscene)
    Gamestate.switch(TitleScene(worldscene, "data/maps/" .. game.maps[game.map_index]))
end

function love.update(dt)
    tick.update(dt)
    game.input:update(dt)
end

function love.draw()
end

local _previous_size

function love.resize(w, h)
    game:_determine_scale()
end

function love.keypressed(key, scancode, isrepeat)
    if isrepeat then
        return
    end

    if scancode == 'return' and love.keyboard.isDown('lalt', 'ralt') then
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
    elseif scancode == 'pause' and game.debug then
        if not game.debug_scene then
            game.debug_scene = DebugScene(m5x7)
        end
        -- FIXME this is incredibly stupid
        if Gamestate.current() ~= game.debug_scene then
            Gamestate.push(game.debug_scene)
        end
    end
end

function love.gamepadpressed(joystick, button)
    -- Tell baton to use whatever joystick was last used
    -- TODO until i can figure out a reliable way to pick a joystick, that
    -- doesn't end up grabbing my dang tablet
    game.input.joystick = joystick
end
