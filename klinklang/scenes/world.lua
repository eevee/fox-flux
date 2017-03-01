local flux = require 'vendor.flux'
local tick = require 'vendor.tick'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local Player = require 'klinklang.actors.player'
local actors_generic = require 'klinklang.actors.generic'
local TriggerZone = require 'klinklang.actors.trigger'
local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'
local whammo = require 'klinklang.whammo'

local tiledmap = require 'klinklang.tiledmap'

local MenuScene = require 'foxflux.scenes.menu'

local CAMERA_MARGIN = 0.33
-- Sets the maximum length of an actor update.
-- 50~60 fps should only do one update, of course; 30fps should do two.
local MIN_FRAMERATE = 45
-- Don't do more than this many updates at once
local MAX_UPDATES = 10

local WorldScene = BaseScene:extend{
    __tostring = function(self) return "worldscene" end,

    music = nil,
    fluct = nil,
    tick = nil,

    using_gamepad = false,
    was_left_down = false,
    was_right_down = false,
    was_up_down = false,
    was_down_down = false,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function WorldScene:init(...)
    BaseScene.init(self, ...)

    self.camera = Vector()
    -- FIXME? i'd rather rely on enter() for this, but the world is drawn via
    -- SceneFader /before/ enter() is called for the first time
    self:_refresh_canvas()

    -- FIXME well, i guess, don't actually fix me, but, this is used to stash
    -- entire maps atm too
    self.stashed_submaps = {}

    -- TODO probably need a more robust way of specifying music
    --self.music = love.audio.newSource('assets/music/square-one.ogg', 'stream')
    --self.music:setLooping(true)
end

function WorldScene:enter()
    --self.music:play()
    self:_refresh_canvas()
end

function WorldScene:resume()
    -- Just in case, whenever we become the current scene, double-check the
    -- canvas size
    self:_refresh_canvas()
end

function WorldScene:_refresh_canvas()
    local w, h = game:getDimensions()

    if self.canvas then
        local cw, ch = self.canvas:getDimensions()
        if w == cw and h == ch then
            return
        end
    end

    self.canvas = love.graphics.newCanvas(w, h)
end

function WorldScene:update(dt)
    -- FIXME could get rid of this entirely if actors had to go through me to
    -- collide
    game.debug_hits = {}

    -- Handle movement input.
    -- Input comes in two flavors: "instant" actions that happen once when a
    -- button is pressed, and "continuous" actions that happen as long as a
    -- button is held down.
    -- "Instant" actions need to be handled in keypressed, but "continuous"
    -- actions need to be handled with an explicit per-frame check.  The
    -- difference is that a press might happen in another scene (e.g. when the
    -- game is paused), which for instant actions should be ignored, but for
    -- continuous actions should start happening as soon as we regain control —
    -- even though we never know a physical press happened.
    -- Walking has the additional wrinkle that there are two distinct inputs.
    -- If both are held down, then we want to obey whichever was held more
    -- recently, which means we also need to track whether they were held down
    -- last frame.
    local is_left_down = game.input:down('left')
    local is_right_down = game.input:down('right')
    local is_up_down = game.input:down('up')
    local is_down_down = game.input:down('down')
    if is_left_down and is_right_down then
        if self.was_left_down and self.was_right_down then
            -- Continuing to hold both keys; do nothing
        elseif self.was_left_down then
            -- Was holding left, also pressed right, so move right
            self.player:decide_walk(1)
        elseif self.was_right_down then
            -- Was holding right, also pressed left, so move left
            self.player:decide_walk(-1)
        else
            -- Miraculously went from holding neither to holding both, so let's
            -- not move at all
            self.player:decide_walk(0)
        end
    elseif is_left_down then
        self.player:decide_walk(-1)
    elseif is_right_down then
        self.player:decide_walk(1)
    else
        self.player:decide_walk(0)
    end
    self.was_left_down = is_left_down
    self.was_right_down = is_right_down
    -- FIXME this is such a fucking mess lmao
    if is_up_down and is_down_down then
        if self.was_up_down and self.was_down_down then
        elseif self.was_up_down then
            self.player:decide_climb(1)
        elseif self.was_down_down then
            self.player:decide_climb(-1)
        else
            self.player:decide_pause_climbing()
        end
    elseif is_up_down then
        -- TODO up+jump doesn't work correctly, but it's a little fiddly, since
        -- you should only resume climbing once you reach the peak of the jump?
        self.player:decide_climb(1)
    elseif is_down_down then
        -- Only start climbing down if this is a NEW press, so that down+jump
        -- doesn't immediately regrab on the next frame
        if not self.was_down_down then
            self.player:decide_climb(-1)
        end
    else
        self.player:decide_pause_climbing()
    end
    self.was_up_down = is_up_down
    self.was_down_down = is_down_down
    -- Jumping is slightly more subtle.  The initial jump is an instant action,
    -- but /continuing/ to jump is a continuous action.  So we handle the
    -- initial jump in keypressed, but abandon a jump here as soon as the key
    -- is no longer held.
    -- FIXME no longer true, but input is handled globally so catching a
    -- spacebar from dialogue is okay
    if game.input:pressed('jump') then
        -- Down + jump also means let go
        if is_down_down then
            self.player:decide_climb(nil)
        end
        self.player:decide_jump()
    end
    if not game.input:down('jump') then
        self.player:decide_abandon_jump()
    end

    -- FIXME this stupid dt thing is so we don't try to do a second "use" after
    -- switching maps (which does a zero update), ugghhh.  i don't know where
    -- else this belongs though?
    if dt > 0 and game.input:pressed('use') then
        if self.player.is_locked then
            -- Do nothing
        elseif self.player.form == 'stone' then
            -- Do nothing
        else
            -- Use inventory item, or nearby thing
            -- FIXME this should be separate keys maybe?
            if self.player.touching_mechanism then
                self.player.touching_mechanism:on_use(self.player)
            elseif self.player.inventory_cursor > 0 then
                self.player.inventory[self.player.inventory_cursor]:on_inventory_use(self.player)
            end
        end
    end

    self.fluct:update(dt)
    self.tick:update(dt)

    -- Update the music to match the player's current position
    local x, y = self.player.pos:unpack()
    local new_music = false
    for shape, music in pairs(self.map.music_zones) do
        -- FIXME don't have a real api for this yet oops
        local x0, y0, x1, y1 = shape:bbox()
        if x0 <= x and x <= x1 and y0 <= y and y <= y1 then
            new_music = music
            break
        end
    end
    if self.music == new_music then
        -- Do nothing
    elseif new_music == false then
        -- Didn't find a zone at all; keep current music
    elseif self.music == nil then
        new_music:setLooping(true)
        new_music:play()
        self.music = new_music
    elseif new_music == nil then
        self.music:stop()
        self.music = nil
    else
        -- FIXME crossfade?
        new_music:setLooping(true)
        new_music:play()
        new_music:seek(self.music:tell())
        self.music:stop()
        self.music = new_music
    end

    -- If the framerate drops significantly below 60fps, do multiple updates.
    -- This avoids objects completely missing each other, as well as subtler
    -- problems like the player's jump height being massively different due to
    -- large acceleration steps.
    -- TODO if the slowdown is due to the updates, not the draw, then this is
    -- not going to help!  might be worth timing this and giving up if it takes
    -- more time than it's trying to simulate
    local updatect = math.max(1, math.min(MAX_UPDATES,
        math.ceil(dt * MIN_FRAMERATE)))
    local subdt = dt / updatect
    for i = 1, updatect do
        for _, actor in ipairs(self.actors) do
            actor:update(subdt)
        end
    end

    -- Note that this will be called every frame after collecting a heart until
    -- the game is saved, but it just iterates over some tables so that's nbd
    if game.is_dirty then
        self:update_heart_counts()
    end

    love.audio.setPosition(self.player.pos.x, self.player.pos.y, 0)
    local fx = 1
    if self.player.facing_left then
        fx = -1
    end
    love.audio.setOrientation(fx, 0, 0, -1, 0, 0)

    self:update_camera()
end

function WorldScene:update_camera()
    -- Update camera position
    -- TODO i miss having a box type
    -- FIXME would like some more interesting features here like smoothly
    -- catching up with the player, platform snapping?
    if self.player then
        -- TODO this focuses on the player's feet!  should be middle of body?  eyes?
        local focusx = math.floor(self.player.pos.x + 0.5)
        local focusy = math.floor(self.player.pos.y + 0.5)
        local w, h = game:getDimensions()
        local mapx, mapy = 0, 0

        local marginx = CAMERA_MARGIN * w
        local x0 = marginx
        local x1 = w - marginx
        local minx = self.map.camera_margin_left
        local maxx = self.map.width - self.map.camera_margin_right - w
        local newx = self.camera.x
        if focusx - newx < x0 then
            newx = focusx - x0
        elseif focusx - newx > x1 then
            newx = focusx - x1
        end
        newx = math.max(minx, math.min(maxx, newx))
        self.camera.x = math.floor(newx)

        local marginy = CAMERA_MARGIN * h
        local y0 = marginy
        local y1 = h - marginy
        local miny = self.map.camera_margin_top
        local maxy = self.map.height - self.map.camera_margin_bottom - h
        local newy = self.camera.y
        if focusy - newy < y0 then
            newy = focusy - y0
        elseif focusy - newy > y1 then
            newy = focusy - y1
        end
        newy = math.max(miny, math.min(maxy, newy))
        if self.player.camera_jitter and self.player.camera_jitter > 0 then
            newy = newy + math.sin(self.player.camera_jitter * math.pi) * 3
            newy = math.max(miny, math.min(maxy, newy))
        end
        self.camera.y = math.floor(newy)
    end
end

function WorldScene:update_heart_counts()
    self.hearts_collected_in_region = 0
    self.hearts_collected_in_map = 0
    local region = self.map:prop('region', '')
    for map_path, hearts in pairs(game.progress.hearts[region] or {}) do
        local heartct = 0
        for heart, collected in pairs(hearts) do
            if collected then
                heartct = heartct + 1
            end
        end
        self.hearts_collected_in_region = self.hearts_collected_in_region + heartct
        if map_path == self.map.path then
            self.hearts_collected_in_map = self.hearts_collected_in_map + heartct
        end
    end
end

function WorldScene:draw()
    local w, h = game:getDimensions()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()

    love.graphics.push('all')
    love.graphics.translate(-self.camera.x, -self.camera.y)

    -- TODO later this can expand into drawing all the layers automatically
    -- (the main problem is figuring out where exactly the actor layer lives)
    self.map:draw_parallax_background(self.camera, w, h)

    -- TODO once the camera is set up, consider rigging the map to somehow
    -- auto-expand to fill the screen?
    -- FIXME don't really like hardcoding layer names here; they /have/ an
    -- order, the main problem is just that there's no way to specify where the
    -- actors should be drawn
    self.map:draw('background', nil, self.camera, w, h)
    self.map:draw('main terrain', nil, self.camera, w, h)

    local actors_faucet
    if self.pushed_actors then
        self:_draw_actors(self.pushed_actors)
    else
        self:_draw_actors(self.actors)
    end

    self.map:draw('objects', nil, self.camera, w, h)
    self.map:draw('foreground', nil, self.camera, w, h)
    self.map:draw('wiring', nil, self.camera, w, h)

    if self.pushed_actors then
        love.graphics.setColor(0, 0, 0, 192)
        love.graphics.rectangle('fill', self.camera.x, self.camera.y, w, h)
        love.graphics.setColor(255, 255, 255)
        -- FIXME stop hardcoding fuckin layer names
        self.map:draw('background', self.submap, self.camera, w, h)
        self.map:draw('main terrain', self.submap, self.camera, w, h)
        self.map:draw(self.submap, self.submap, self.camera, w, h)
        self:_draw_actors(self.actors)
        self.map:draw('objects', self.submap, self.camera, w, h)
        self.map:draw('foreground', self.submap, self.camera, w, h)
        self.map:draw('wiring', self.submap, self.camera, w, h)
    end

    -- Draw a keycap when the player is next to something touchable
    -- FIXME i seem to put this separately in every game?  standardize somehow?
    if self.player.touching_mechanism then
        if self.player.form ~= 'stone' then
            self:_draw_use_key_hint(self.player.pos + Vector(0, -80))
        end
    end

    if game.debug then
        --[[
        for shape in pairs(self.collider.shapes) do
            shape:draw('line')
        end
        ]]
        if game.debug_twiddles.show_shapes then
            for _, actor in ipairs(self.actors) do
                if actor.shape then
                    love.graphics.setColor(255, 255, 0, 128)
                    actor.shape:draw('fill')
                end
                if actor.pos then
                    love.graphics.setColor(255, 0, 0)
                    love.graphics.circle('fill', actor.pos.x, actor.pos.y, 2)
                    love.graphics.setColor(255, 255, 255)
                    love.graphics.circle('line', actor.pos.x, actor.pos.y, 2)
                end
            end
        end

        if game.debug_twiddles.show_collision then
            for hit, collision in pairs(game.debug_hits) do
                if collision.touchtype > 0 then
                    -- Collision: red
                    love.graphics.setColor(255, 0, 0, 128)
                elseif collision.touchtype < 0 then
                    -- Overlap: blue
                    love.graphics.setColor(0, 64, 255, 128)
                else
                    -- Touch: green
                    love.graphics.setColor(0, 192, 0, 128)
                end
                hit:draw('fill')
                --love.graphics.setColor(255, 255, 0)
                --local x, y = hit:bbox()
                --love.graphics.print(("%0.2f"):format(d), x, y)

                love.graphics.setColor(255, 0, 255)
                local x0, y0, x1, y1 = collision.shape:bbox()
                local x, y = math.floor((x0 + x1) / 2), math.floor((y0 + y1) / 2)
                for normal, normal1 in pairs(collision.normals) do
                    local startpt = Vector(x, y)
                    local endpt = startpt + normal1 * 8
                    local perp = normal1:perpendicular()
                    local arrowpt1 = endpt + perp * 3
                    local arrowpt2 = endpt - perp * 3
                    local arrowpt3 = endpt + normal1 * 3
                    love.graphics.line(x, y, endpt.x, endpt.y)
                    love.graphics.polygon('fill', arrowpt1.x, arrowpt1.y, arrowpt2.x, arrowpt2.y, arrowpt3.x, arrowpt3.y)
                end
            end
        end
    end

    love.graphics.pop()

    love.graphics.setCanvas()
    love.graphics.draw(self.canvas, 0, 0, 0, game.scale, game.scale)

    if game.debug and game.debug_twiddles.show_blockmap then
        self:_draw_blockmap()
    end

    love.graphics.push('all')
    love.graphics.scale(game.scale, game.scale)
    local function draw_outlined_text(text, x, y)
        love.graphics.setColor(32, 32, 32)
        love.graphics.draw(text, x + 2, y)
        love.graphics.draw(text, x - 2, y)
        love.graphics.draw(text, x, y + 2)
        love.graphics.draw(text, x, y - 2)
        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(text, x, y)
    end
    local sprite = game.sprites['heart counter']:instantiate()
    local sw, sh = sprite:getDimensions()
    local text = love.graphics.newText(m5x7, ("x %d"):format(self.hearts_collected_in_region))
    local padding = 8
    local tw = text:getWidth() + 4
    local x = w - math.max(64, tw) - padding * 2 - sw
    sprite:draw_anchorless(Vector(x, padding))
    x = x + sw + padding + 2
    local y = math.floor(padding + (32 - m5x7:getHeight() * m5x7:getLineHeight()) / 2)
    draw_outlined_text(text, x, y)
    if self.hearts_total_in_map > 0 then
        -- Position "n / m" so that the "/" is centered below the "x" of the
        -- total heart count
        local center = m5x7:getWidth(("%d /"):format(self.hearts_collected_in_map)) - m5x7:getWidth("/") / 2
        x = x + m5x7:getWidth("x") / 2 - center
        y = y + 32
        local text = love.graphics.newText(m5x7, ("%d / %d"):format(self.hearts_collected_in_map, self.hearts_total_in_map))
        draw_outlined_text(text, x, y)
    end

    -- FIXME put this and the debug stuff on a separate "layer" which doesn't have to live here
    local frame = game.sprites[self.player.inventory_frame_sprite_name]:instantiate()
    frame:draw_anchorless(Vector(0, 0))
    love.graphics.setScissor(16 * game.scale, 16 * game.scale, love.graphics.getWidth(), 32 * game.scale)
    local name = love.graphics.newText(m5x7, self.player.inventory[self.player.inventory_cursor].display_name)
    local dy = 32
    if self.inventory_switch then
        if self.inventory_switch.progress < 1 then
            dy = math.floor(self.inventory_switch.progress * 32)
            local sprite = game.sprites[self.inventory_switch.old_item.sprite_name]:instantiate()
            sprite:draw_anchorless(Vector(16, 16 - dy))
            love.graphics.draw(self.inventory_switch.new_name, 64, 32 - self.inventory_switch.new_name:getHeight() / 2 + 32 - dy)
        else
            love.graphics.setColor(255, 255, 255, self.inventory_switch.name_opacity * 255)
            love.graphics.draw(self.inventory_switch.new_name, 64, 32 - self.inventory_switch.new_name:getHeight() / 2)
            love.graphics.setColor(255, 255, 255)
        end
    end

    if self.player.form ~= 'stone' then
        local sprite = game.sprites[self.player.inventory[self.player.inventory_cursor].sprite_name]:instantiate()
        sprite:draw_anchorless(Vector(16, 16 + 32 - dy))
        love.graphics.setScissor()
        if not self.player.touching_mechanism then
            self:_draw_use_key_hint(Vector(64, 48))
        end
    end
    love.graphics.pop()

    love.graphics.push('all')
    --[[
    local sprite = game.sprites['keycap']:instantiate()
    sprite:draw_at(Vector(36, 40))
    love.graphics.setColor(52, 52, 52)
    local keylen = m5x7:getWidth("E")
    local line_height = m5x7:getHeight()
    love.graphics.print("E", 36 + (32 - keylen) / 2, 40 + (32 - line_height) / 2)
    if #self.player.inventory > 1 then
        love.graphics.setColor(255, 255, 255)
        sprite:draw_at(Vector(0, 40))
        local keylen = m5x7:getWidth("Q")
        love.graphics.setColor(52, 52, 52)
        love.graphics.print("Q", 0 + (32 - keylen) / 2, 40 + (32 - line_height) / 2)
    end
    ]]
    love.graphics.pop()
end

function WorldScene:_draw_actors(actors)
    local sorted_actors = {}
    for k, v in ipairs(actors) do
        sorted_actors[k] = v
    end

    table.sort(sorted_actors, function(actor1, actor2)
        return (actor1.z or 0) < (actor2.z or 0)
    end)

    for _, actor in ipairs(sorted_actors) do
        actor:draw()
    end
end

-- Note: pos is the center of the hint; sprites should have their anchors at
-- their centers too
function WorldScene:_draw_use_key_hint(anchor)
    local letter, sprite
    -- TODO just get the actual key/button from game.input
    if game.input:getActiveDevice() == 'joystick' then
        letter = 'X'
        sprite = game.sprites['keycap button']:instantiate()
    else
        letter = love.keyboard.getKeyFromScancode('e'):upper()
        sprite = game.sprites['keycap key']:instantiate()
    end
    sprite:draw_at(anchor)
    love.graphics.push('all')
    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(m5x7small)
    local tw = m5x7small:getWidth(letter)
    local th = m5x7small:getHeight() * m5x7small:getLineHeight()
    love.graphics.print(letter, math.floor(anchor.x - tw / 2 + 0.5), math.floor(anchor.y - 8))
    love.graphics.pop()
end

function WorldScene:_draw_blockmap()
    love.graphics.push('all')
    love.graphics.setColor(255, 255, 255, 64)
    love.graphics.scale(game.scale, game.scale)

    local blockmap = self.collider.blockmap
    local blocksize = blockmap.blocksize
    local x0 = -self.camera.x % blocksize
    local y0 = -self.camera.y % blocksize
    local w, h = game:getDimensions()
    for x = x0, w, blocksize do
        love.graphics.line(x, 0, x, h)
    end
    for y = y0, h, blocksize do
        love.graphics.line(0, y, w, y)
    end

    for x = x0, w, blocksize do
        for y = y0, h, blocksize do
            local a, b = blockmap:to_block_units(self.camera.x + x, self.camera.y + y)
            love.graphics.print((" %d, %d"):format(a, b), x, y)
        end
    end

    love.graphics.pop()
end

function WorldScene:resize(w, h)
    self:_refresh_canvas()
end

-- FIXME this is really /all/ game-specific
function WorldScene:keypressed(key, scancode, isrepeat)
    if isrepeat then
        return
    end

    if scancode == 'escape' then
        Gamestate.push(MenuScene())
    elseif scancode == 'q' then
        do return end
        -- Switch inventory items
        if not self.inventory_switch or self.inventory_switch.progress == 1 then
            local old_item = self.player.inventory[self.player.inventory_cursor]
            self.player.inventory_cursor = self.player.inventory_cursor + 1
            if self.player.inventory_cursor > #self.player.inventory then
                self.player.inventory_cursor = 1
            end
            if self.inventory_switch then
                self.inventory_switch.event:stop()
            end
            self.inventory_switch = {
                old_item = old_item,
                new_name = love.graphics.newText(m5x7, self.player.inventory[self.player.inventory_cursor].display_name),
                progress = 0,
                name_opacity = 1,
            }
            local event = self.fluct:to(self.inventory_switch, 0.33, { progress = 1 })
                :ease('linear')
                :after(0.33, { name_opacity = 0 })
                :delay(1)
                :oncomplete(function() self.inventory_switch = nil end)
            self.inventory_switch.event = event
        end
    end
end

function WorldScene:mousepressed(x, y, button, istouch)
    if game.debug and button == 2 then
        self.player:move_to(Vector(
            x / game.scale + self.camera.x,
            y / game.scale + self.camera.y))
        self.player.velocity = Vector()
    end
end

--------------------------------------------------------------------------------
-- API

function WorldScene:load_map(map, spot_name)
    -- Unload previous map; this allows actors to clean up global resources,
    -- such as ambient sounds.
    -- TODO i'm not sure this is the right thing to do; it would be wrong for
    -- NEON PHASE, for example, since there we stash a map to go back to it
    -- later!  i'm also not sure it should apply to the player?  but i only
    -- need it in the first place to stop the laser sound.  wow audio is hard
    if self.actors then
        for i = #self.actors, 1, -1 do
            local actor = self.actors[i]
            self.actors[i] = nil
            if actor then
                actor:on_leave()
            end
        end
    end

    if spot_name then
        -- FIXME this is very much a hack that happens to work with the design
        -- of fox flux; there should be a more explicit way of setting save
        -- points
        game:set_save_spot(map, spot_name)
    else
        -- If this map declares its attachment to an overworld, use that point
        -- as a save point
        local overworld_map = map:prop('overworld map')
        local overworld_spot = map:prop('overworld spot')
        if overworld_map and overworld_spot then
            game:set_save_spot(overworld_map, overworld_spot)
        end
    end

    self.map = map
    --self.music = nil  -- FIXME not sure when this should happen; isaac vs neon are very different
    self.fluct = flux.group()
    self.tick = tick.group()

    if self.stashed_submaps[map] then
        self.actors = self.stashed_submaps[map].actors
        self.collider = self.stashed_submaps[map].collider
        self.camera = self.player.pos:clone()
        self:update_camera()
        -- XXX this is really half-assed, relies on the caller to add the player back to the map too
        return
    end

    self.actors = {}
    self.collider = whammo.Collider(4 * map.tilewidth)
    -- FIXME this is useful sometimes (temporary hop to another map), but not
    -- always (reloading the map for isaac); find a way to reconcile
    --[[
    self.stashed_submaps[map] = {
        actors = self.actors,
        collider = self.collider,
    }
    ]]

    -- TODO this seems clearly wrong, especially since i don't clear the
    -- collider, but it happens to work (i think)
    map:add_to_collider(self.collider)

    local player_start
    if spot_name then
        player_start = self.map.named_spots[spot_name]
        if not player_start then
            error(("No spot named %s on map %s"):format(spot_name, map))
        end
    else
        player_start = self.map.player_start
        if not player_start then
            error(("No player start found on map %s"):format(map))
        end
    end
    if self.player then
        self.player:move_to(player_start:clone())
    else
        self.player = Player(player_start:clone())
    end

    -- TODO this seems more a candidate for an 'enter' or map-switch event
    self:_create_actors()

    -- Count all the hearts on all submaps
    self.hearts_total_in_map = 0
    local heart_list = {}
    local heart_list_set = {}
    for _, template in ipairs(self.map.actor_templates) do
        local class = actors_base.Actor:get_named_type(template.name)
        if class and class.is_heart then
            self.hearts_total_in_map = self.hearts_total_in_map + 1

            local persistence_key = template.properties and template.properties['persistence key']
            if not persistence_key then
                print(
                    ("WARNING: found a heart with no persistence key on map %s at %s")
                    :format(self.map.path, template.position))
            elseif heart_list_set[persistence_key] then
                print(
                    ("WARNING: found two hearts with the same persistence key %s on map %s at %s, %s")
                    :format(persistence_key, self.map.path,
                        heart_list_set[persistence_key].position, template.position))
            else
                table.insert(heart_list, persistence_key)
                heart_list_set[persistence_key] = template
            end
        end
    end
    self.map_region = self.map:prop('region', '')
    game:update_heart_list(self.map, heart_list)
    self:update_heart_counts()

    -- FIXME this is invasive
    -- FIXME should probably just pass the slightly-munged object right to the constructor, instead of special casing these
    -- FIXME could combine this with player start detection maybe
    for _, layer in pairs(map.layers) do
        if layer.type == 'objectgroup' and layer.submap == nil then
            for _, object in ipairs(layer.objects) do
                if object.type == 'trigger' then
                    self:add_actor(TriggerZone(
                        Vector(object.x, object.y),
                        Vector(object.width, object.height),
                        object.properties))
                elseif object.type == 'ladder' then
                    local shape = tiledmap.tiled_shape_to_whammo_shape(object)
                    self:add_actor(actors_generic.LadderZone(
                        Vector(object.x, object.y), shape))
                end
            end
        end
    end

    -- FIXME putting the player last is really just a z hack to make the player
    -- draw in front of everything else
    self:add_actor(self.player)

    -- Rez the player if necessary.  This MUST happen after moving the player
    -- (and SHOULD happen after populating the world, anyway) because it does a
    -- zero-duration update, and if the player is still touching whatever
    -- killed them, they'll instantly die again.
    if self.player.is_dead then
        -- TODO should this be a more general 'reset'?
        self.player:resurrect()
    end

    self.camera = self.player.pos:clone()
    self.camera.y = self.camera.y - self.map.height

    -- Advance the world by zero time to put it in a consistent state (e.g.
    -- figure out what's on the ground, update the camera)
    self:update(0)
end

function WorldScene:reload_map()
    self:load_map(self.map)
end

function WorldScene:_create_actors(submap)
    for _, template in ipairs(self.map.actor_templates) do
        if template.submap == submap then
            local class = actors_base.Actor:get_named_type(template.name)
            local position = template.position:clone()
            local actor = class(position, template.properties)
            -- FIXME this feels...  hokey...
            if actor.sprite.anchor then
                actor:move_to(position + actor.sprite.anchor)
            end
            self:add_actor(actor)
        end
    end
end

function WorldScene:enter_submap(name)
    -- FIXME this is extremely half-baked
    if self.submap == nil then
        self.pushed_actors = self.actors
        self.pushed_collider = self.collider
    end
    self.submap = name
    self:remove_actor(self.player)

    -- FIXME get rid of pushed in favor of this?  but still need to establish the stack
    if self.stashed_submaps[name] then
        self.actors = self.stashed_submaps[name].actors
        self.collider = self.stashed_submaps[name].collider
        self:add_actor(self.player)
        return
    end

    self.actors = {}
    self.collider = whammo.Collider(4 * self.map.tilewidth)
    self.stashed_submaps[name] = {
        actors = self.actors,
        collider = self.collider,
    }
    self.map:add_to_collider(self.collider, self.submap)
    self:add_actor(self.player)

    self:_create_actors(self.submap)

    -- FIXME this is also invasive
    -- FIXME UGGH and it's copy-pasted
    for _, layer in pairs(self.map.layers) do
        if layer.type == 'objectgroup' and layer.submap == self.submap then
            for _, object in ipairs(layer.objects) do
                if object.type == 'trigger' then
                    self:add_actor(TriggerZone(
                        Vector(object.x, object.y),
                        Vector(object.width, object.height),
                        object.properties))
                elseif object.type == 'ladder' then
                    local shape = tiledmap.tiled_shape_to_whammo_shape(object)
                    self:add_actor(actors_generic.LadderZone(
                        Vector(object.x, object.y), shape))
                end
            end
        end
    end
end

function WorldScene:leave_submap(name)
    -- FIXME this is extremely half-baked
    self.submap = nil
    self:remove_actor(self.player)
    self.actors = self.pushed_actors
    self.collider = self.pushed_collider
    self.pushed_actors = nil
    self.pushed_collider = nil
    self:add_actor(self.player)
end

function WorldScene:add_actor(actor)
    table.insert(self.actors, actor)

    if actor.shape then
        -- TODO what happens if the shape changes?
        self.collider:add(actor.shape, actor)
    end

    actor:on_enter()
end

function WorldScene:remove_actor(actor)
    -- TODO what if the actor is the player...?  should we unset self.player?
    actor:on_leave()

    -- TODO maybe an index would be useful
    for i, an_actor in ipairs(self.actors) do
        if actor == an_actor then
            local last = #self.actors
            self.actors[i] = self.actors[last]
            self.actors[last] = nil
            break
        end
    end

    if actor.shape then
        self.collider:remove(actor.shape)
    end
end


return WorldScene
