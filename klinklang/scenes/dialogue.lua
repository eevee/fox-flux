local utf8 = require 'utf8'

local tick = require 'vendor.tick'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local BaseScene = require 'klinklang.scenes.base'
local Object = require 'klinklang.object'

local SCROLL_RATE = 64  -- characters per second

-- Magic rendering numbers
local TEXT_MARGIN_X = 16
local TEXT_MARGIN_Y = 12


local function _evaluate_condition(condition)
    if condition == nil then
        return true
    elseif type(condition) == 'string' then
        return game.progress.flags[condition]
    else
        return condition()
    end
end


-- TODO maybe this should be a /speaker/ object?
local StackedSprite = Object:extend{
    is_talking = false,
}

-- TODO defaults, explicit posing, named pose shortcuts, persistent additions like neon's weight, while_talking
function StackedSprite:init(data)
    if type(data) == 'string' then
        local sprite = game.sprites[data]:instantiate()
        self.sprites = { default = sprite }
        self.sprite_order = {'default'}
        self.sprite_poses = { default = sprite.pose }
        self.sprite_talking_map = { default = {} }
        self.sprite_metaposes = {}
        -- FIXME this seems really stupid for the extremely common case
        for pose_name in pairs(sprite.spriteset.poses) do
            self.sprite_metaposes[pose_name] = { default = pose_name }
        end
    else
        self.sprites = {}
        self.sprite_order = {}
        self.sprite_poses = {}
        self.sprite_talking_map = {}
        self.sprite_metaposes = data
        for _, datum in ipairs(data) do
            local sprite = game.sprites[datum.sprite_name]:instantiate()
            self.sprites[datum.name] = sprite
            table.insert(self.sprite_order, datum.name)
            if datum.default == false then
                self.sprite_poses[datum.name] = false
            elseif datum.default then
                sprite:set_pose(datum.default)
                self.sprite_poses[datum.name] = datum.default
            else
                self.sprite_poses[datum.name] = sprite.pose
            end
            self.sprite_talking_map[datum.name] = datum.while_talking or {}
        end
    end
end

function StackedSprite:change_pose(pose)
    if type(pose) == 'string' or #pose == 0 then
        pose = {pose}
    end

    for _, metapose_name in ipairs(pose) do
        local metapose
        if type(metapose_name) == 'table' then
            metapose = metapose_name
        else
            metapose = self.sprite_metaposes[metapose_name]
        end
        for layer_name, subpose in pairs(metapose) do
            -- TODO consult current is_talking
            self.sprite_poses[layer_name] = subpose
            if subpose ~= false then
                self.sprites[layer_name]:set_pose(subpose)
            end
        end
    end
end

function StackedSprite:set_talking(is_talking)
    if is_talking ~= self.is_talking then
        for name, sprite in pairs(self.sprites) do
            local pose = self.sprite_poses[name]
            if is_talking then
                local talking_pose = self.sprite_talking_map[name][pose]
                if talking_pose ~= nil then
                    pose = talking_pose
                end
            end

            -- FIXME wait, what if you want to use 'false' for talking?  i
            -- store only the current not-talking pose in sprite_poses...
            if pose ~= false then
                sprite:set_pose(pose)
            end
        end
    end

    self.is_talking = is_talking
end

-- TODO this should help, right
function StackedSprite:_set_sprite_pose()
end

-- FIXME what if the subsprites are different dimensions, oh goodness
function StackedSprite:getDimensions()
    return self.sprites[self.sprite_order[1]]:getDimensions()
end

for _, func in ipairs{'set_scale', 'set_facing_right', 'update', 'draw'} do
    StackedSprite[func] = function(self, ...)
        for _, sprite in pairs(self.sprites) do
            sprite[func](sprite, ...)
        end
    end
end

function StackedSprite:draw_anchorless(pos)
    for _, name in ipairs(self.sprite_order) do
        if self.sprite_poses[name] then
            self.sprites[name]:draw_anchorless(pos)
        end
    end
end




local DialogueScene = BaseScene:extend{
    __tostring = function(self) return "dialoguescene" end,

    -- Default speaker settings; set in a subclass (or just monkeypatch)
    default_background = nil,
    default_color = {255, 255, 255},
    default_shadow = {0, 0, 0, 128},
}

-- TODO as with DeadScene, it would be nice if i could formally eat keyboard input
-- FIXME document the shape of speakers/script, once we know what it is
function DialogueScene:init(speakers, script)
    BaseScene.init(self)

    self.wrapped = nil
    self.tick = tick.group()

    -- FIXME unhardcode some more of this, adjust it on resize
    local w, h = game:getDimensions()
    self.speaker_height = 160
    local boxheight = 112
    local winheight = h
    -- FIXME cerise is slightly too big, arrgghhh
    self.speaker_scale = math.floor((winheight - boxheight) / self.speaker_height)

    -- TODO a good start, but
    self.speakers = {}
    local claimed_positions = {}
    local seeking_position = {}
    for name, speaker in pairs(speakers) do
        -- FIXME maybe speakers should only provide a spriteset so i'm not
        -- changing out from under them
        if speaker.isa and speaker:isa(actors_base.BareActor) then
            local actor = speaker
            speaker = {
                position = actor.dialogue_position,
                color = actor.dialogue_color,
                shadow = actor.dialogue_shadow,
            }
            if actor.dialogue_sprite_name then
                speaker.sprite = game.sprites[actor.dialogue_sprite_name]:instantiate()
            elseif actor.dialogue_sprites then
                speaker.sprite = StackedSprite(actor.dialogue_sprites)
            else
                error()
            end
            if actor.dialogue_background then
                speaker.background = game.resource_manager:load(actor.dialogue_background)
            end
            if actor.dialogue_chatter_sound then
                speaker.chatter_sfx = game.resource_manager:get(actor.dialogue_chatter_sound)
            end
        end
        self.speakers[name] = speaker

        if speaker.sprite then
            speaker.sprite:set_scale(self.speaker_scale)
        end

        if type(speaker.position) == 'table' then
            -- This is a list of preferred positions; the speaker will actually
            -- get the first one not otherwise spoken for
            seeking_position[name] = speaker.position
        elseif speaker.position then
            claimed_positions[speaker.position] = true
        elseif speaker.sprite then
            error(("Speaker %s has a sprite but no position"):format(name))
        end
    end

    -- Resolve position preferences
    while true do
        local new_positions = {}
        local any_remaining = false
        for name, positions in pairs(seeking_position) do
            any_remaining = true
            for _, position in ipairs(positions) do
                if not claimed_positions[position] then
                    if new_positions[position] then
                        -- This is mainly to prevent nondeterministic results
                        -- TODO maybe there are some better rules for this,
                        -- like if one only has one pref left but the other has
                        -- two
                        error(("position conflict: %s and %s both want %s, please resolve manually")
                            :format(name, new_positions[position], position))
                    end
                    new_positions[position] = name
                    break
                end
            end
        end
        if not any_remaining then
            break
        end

        for position, name in pairs(new_positions) do
            self.speakers[name].position = position
            seeking_position[name] = nil
            claimed_positions[position] = true
        end
    end
    for name, speaker in pairs(self.speakers) do
        if speaker.sprite and speaker.position == 'right' then
            speaker.sprite:set_facing_right(false)
        end
    end

    self.script = script
    self.labels = {}  -- name -> index
    for i, step in ipairs(self.script) do
        if step.label then
            if self.labels[step.label] then
                error(("Duplicate label: %s"):format(step.label))
            end
            self.labels[step.label] = i
        end
    end

    -- TODO should rig up a whole thing for who to display and where, pose to use, etc., but for now these bits are hardcoded i guess
    self.font = m5x7  -- TODO global, should use resourcemanager probably
    self.font_height = math.ceil(self.font:getHeight() * self.font:getLineHeight())
    
    -- State of the current phrase
    self.curphrase = 1
    self.curline = 1
    self.curchar = 0
    self.phrase_lines = nil  -- set below
    self.phrase_speaker = nil
    self.phrase_timer = nil  -- counts in time * SCROLL_RATE; every time it goes up by 1, a new character should appear
    self.last_was_space = true
    self.chatter_enabled = true

    self.state = 'start'
    self.hesitating = false

    -- TODO magic numbers
    self.wraplimit = w - TEXT_MARGIN_X * 2

    self.script_index = 0

    self:_advance_script()
end

function DialogueScene:enter(previous_scene)
    self.wrapped = previous_scene
end

function DialogueScene:update(dt)
    -- Let the player hold the B button for max dialogue speed, but stop at
    -- menus
    -- FIXME this causes a character or two to show while trying to execute a
    -- scenefade
    -- FIXME put this in baton
    local holding_b = love.keyboard.isScancodeDown('d')
    for i, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            if joystick:isGamepadDown('b') then
                holding_b = true
                break
            end
        end
    end
    if game.debug and holding_b then
        if self.hesitate_delay then
            self.hesitate_delay:stop()
            self.hesitating = false
        end
        self:_advance_script()
    end

    -- Do some things
    if dt > 0 and not self.hesitating then
        if game.input:pressed('accept') then
            if self.state == 'menu' then
                self:_cursor_accept()
            else
                self:_advance_script()
            end
        elseif game.input:pressed('up') then
            self:_cursor_up()
        elseif game.input:pressed('down') then
            self:_cursor_down()
        end
    end

    self.tick:update(dt)

    for _, speaker in pairs(self.speakers) do
        if speaker.sprite then
            speaker.sprite:update(dt)
        end
    end

    if self.state == 'speaking' then
        self.phrase_timer = self.phrase_timer + dt * SCROLL_RATE
        local need_redraw = (self.phrase_timer >= 1)
        -- Show as many new characters as necessary, based on time elapsed
        while self.phrase_timer >= 1 do
            -- Advance cursor, continuing across lines if necessary.
            -- curchar is used as the end of a slice, so we want it to point to
            -- the /end/ of a UTF-8 byte sequence.  To get that, we ask
            -- utf8.offset for the start of the SECOND character after the
            -- current one, then subtract a byte to get the end of the first
            -- character.  (The utf8 library apparently saw this use case
            -- coming, because it will happily return one byte past the end of
            -- the string as an offset.)
            local second_char_offset = utf8.offset(self.phrase_lines[self.curline], 2, self.curchar + 1)
            if second_char_offset then
                self.curchar = second_char_offset - 1
            else
                -- There is no second byte, so we've hit the end of the line
                self.phrase_texts[self.curline] = love.graphics.newText(self.font, self.phrase_lines[self.curline])
                self.curline = self.curline + 1
                self.curchar = 0

                if self.curline == #self.phrase_lines + 1 then
                    self.state = 'waiting'
                    self.phrase_timer = 0
                    self:_hesitate()
                    if self.phrase_speaker.sprite and self.phrase_speaker.sprite.set_talking then
                        self.phrase_speaker.sprite:set_talking(false)
                    end
                    break
                end

                -- If we just maxed out the text box, pause before continuing
                -- FIXME hardcoded max lines
                -- FIXME this will pause on /every/ extra line; is that right?
                if self.curline > 3 then
                    self.state = 'waiting'
                    self.phrase_timer = 0
                    self:_hesitate()
                    if self.phrase_speaker.sprite and self.phrase_speaker.sprite.set_talking then
                        self.phrase_speaker.sprite:set_talking(false)
                    end
                    break
                end
            end
            -- Count a non-whitespace character against the timer.
            -- Note that this is a byte slice of the end of a UTF-8 character,
            -- but spaces are a single byte in UTF-8, so it's fine.
            if string.sub(self.phrase_lines[self.curline], self.curchar, self.curchar) == " " then
                self.last_was_space = true
            else
                if self.last_was_space and self.chatter_enabled and self.phrase_speaker.chatter_sfx then
                    local sfx = self.phrase_speaker.chatter_sfx:clone()
                    -- Pitch is exponential, whereas math.random() is linear;
                    -- multiplying two random numbers compensates somewhat by
                    -- adding a significant bias towards the low end
                    local pitch = 1 + math.random() * math.random() * 0.5
                    sfx:setPitch(pitch)
                    sfx:play()

                    self.chatter_enabled = false
                    self.tick:delay(function()
                        self.chatter_enabled = true
                    end, sfx:getDuration() / 4)
                end
                self.last_was_space = false
                self.phrase_timer = self.phrase_timer - 1
            end
        end
        -- Re-render the visible part of the current line if the above loop
        -- made any progress.  Note that it's important to NOT do this if we
        -- haven't shown any of the current line yet, or we might shift
        -- everything up just to draw a blank line.
        if need_redraw and self.curchar > 0 then
            self.phrase_texts[self.curline] = love.graphics.newText(
                self.font,
                string.sub(self.phrase_lines[self.curline], 1, self.curchar))
        end
    end
end

function DialogueScene:_hesitate(time)
    -- Just in case this is a very short phrase, or the player tried to fill
    -- out the box just before it finished naturally (and missed), wait for a
    -- brief time before allowing a button press to go through.
    time = time or 0.1
    self.hesitating = true
    if self.hesitate_delay then
        self.hesitate_delay:stop()
    end
    self.hesitate_delay = self.tick:delay(function()
        self.hesitating = false
        self.hesitate_delay = nil
    end, time)
end

function DialogueScene:_advance_script()
    if self.hesitating then
        return
    end

    -- Fill the textbox
    if self.state == 'speaking' then
        -- FIXME hardcoding max lines again
        local lastline
        if self.curline > 3 then
            lastline = self.curline
        else
            lastline = math.min(3, #self.phrase_lines)
        end

        for l = self.curline, lastline do
            self.phrase_texts[l] = love.graphics.newText(self.font, self.phrase_lines[l])
        end
        self.curline = lastline + 1
        self.curchar = 0
        self.state = 'waiting'
        self:_hesitate()
        if self.phrase_speaker.sprite and self.phrase_speaker.sprite.set_talking then
            self.phrase_speaker.sprite:set_talking(false)
        end
        return
    elseif self.state == 'menu' then
        return
    end

    -- State should be 'waiting' if we got here

    if self.phrase_lines and self.curline <= #self.phrase_lines then
        -- We paused in the middle of a phrase (because it was too long), so
        -- just continue from here
        self.state = 'speaking'
        if self.phrase_speaker.sprite and self.phrase_speaker.sprite.set_talking then
            self.phrase_speaker.sprite:set_talking(true)
        end
        return
    end
    -- FIXME another check required because script_index is initially zero...
    if self.curphrase and self.script[self.script_index] and self.curphrase < #self.script[self.script_index] then
        -- Advance to the next phrase in the current step
        self.curphrase = self.curphrase + 1
        self.curline = 1
        self.curchar = 0
        local _textwidth
        _textwidth, self.phrase_lines = self.font:getWrap(self.script[self.script_index][self.curphrase], self.wraplimit)
        self.phrase_texts = {}
        self.last_was_space = true
        self.state = 'speaking'
        if self.phrase_speaker.sprite and self.phrase_speaker.sprite.set_talking then
            self.phrase_speaker.sprite:set_talking(true)
        end
        return
    end

    while true do
        if self.script_index >= #self.script then
            -- TODO actually not sure what should happen here
            self.state = 'done'
            Gamestate.pop()
            return
        end
        self.script_index = self.script_index + 1
        local step = self.script[self.script_index]

        -- Flags
        if step.set then
            game.progress.flags[step.set] = true
        end

        -- Pose changes can happen on any step
        if step.pose then
            -- TODO this is super hokey at the moment dang
            local speaker = self.speakers[step.speaker]
            speaker.pose = step.pose
            if speaker.sprite then
                speaker.sprite:change_pose(step.pose)
            end
        end

        if #step > 0 then
            self.state = 'speaking'
            local _textwidth
            _textwidth, self.phrase_lines = self.font:getWrap(step[1], self.wraplimit)
            self.phrase_texts = {}
            self.phrase_speaker = self.speakers[step.speaker]
            if self.phrase_speaker.sprite and self.phrase_speaker.sprite.set_talking then
                self.phrase_speaker.sprite:set_talking(true)
            end
            self.phrase_timer = 0
            self.last_was_space = true
            self.curphrase = 1
            self.curline = 1
            self.curchar = 0
            break
        elseif step.menu then
            self.state = 'menu'
            self:_hesitate(0.25)
            self.phrase_speaker = self.speakers[step.speaker]
            self.menu_items = {}
            self.menu_cursor = 1
            self.menu_top = 1
            self.menu_top_line = 1
            for i, item in ipairs(step.menu) do
                if _evaluate_condition(item.condition) then
                    local jump = item[1]
                    local _textwidth, lines = self.font:getWrap(item[2], self.wraplimit)
                    local texts = {}
                    for i, line in ipairs(lines) do
                        texts[i] = love.graphics.newText(self.font, line)
                    end
                    table.insert(self.menu_items, {
                        jump = jump,
                        lines = lines,
                        texts = texts,
                    })
                end
            end
            break
        elseif step.jump then
            -- FIXME would be nice to scan the script for bad jumps upfront
            if _evaluate_condition(step.condition) then
                -- FIXME fuck this -1
                self.script_index = self.labels[step.jump] - 1
            end
        elseif step.execute then
            -- FIXME you could reasonably have this alongside a jump, etc
            if _evaluate_condition(step.condition) then
                step.execute()
            end
        elseif step.bail then
            self.state = 'done'
            Gamestate.pop()
            return
        end
    end
end

function DialogueScene:_cursor_up()
    if self.state ~= 'menu' then
        return
    end
    if self.menu_cursor == 1 then
        return
    end

    -- Move up just enough to see the entirety of the newly-selected item.
    -- If it's already visible, we're done; otherwise, just put it at the top
    if self.menu_top >= self.menu_cursor - 1 then
        self.menu_top = self.menu_cursor - 1
        self.menu_top_line = 1
    end

    self.menu_cursor = self.menu_cursor - 1
end

function DialogueScene:_cursor_down()
    if self.state ~= 'menu' then
        return
    end
    if self.menu_cursor == #self.menu_items then
        return
    end

    -- Move down just enough to see the entirety of the newly-selected item.
    -- First, figure out where it is relative to the top of the dialogue box
    local relative_row = #self.menu_items[self.menu_top].lines - self.menu_top_line + 1
    for l = self.menu_top + 1, self.menu_cursor do
        relative_row = relative_row + #self.menu_items[l].lines
    end
    -- FIXME hardcoded the line count
    relative_row = relative_row + math.min(3, #self.menu_items[self.menu_cursor + 1].lines)

    for i = 1, relative_row - 3 do
        self.menu_top_line = self.menu_top_line + 1
        if self.menu_top_line > #self.menu_items[self.menu_top].lines then
            self.menu_top = self.menu_top + 1
            self.menu_top_line = 1
        end
    end

    self.menu_cursor = self.menu_cursor + 1
end

function DialogueScene:_cursor_accept()
    if self.state ~= 'menu' then
        return
    end

    local item = self.menu_items[self.menu_cursor]
    -- FIXME lol this -1 is a dumb hack because _advance_script always starts by moving ahead by 1
    self.script_index = self.labels[item.jump] - 1
    self.state = 'waiting'
    self:_advance_script()
end

function DialogueScene:draw()
    self.wrapped:draw()

    love.graphics.push('all')
    love.graphics.scale(game.scale, game.scale)
    love.graphics.setColor(0, 0, 0, 64)
    love.graphics.rectangle('fill', 0, 0, game:getDimensions())
    love.graphics.setColor(255, 255, 255)

    -- Draw the dialogue box, which is slightly complicated because it involves
    -- drawing the ends and then repeating the middle bit to fit the screen
    -- size
    local background = self.phrase_speaker.background or self.default_background
    -- TODO this feels rather hardcoded; surely the background should flex to fit the height rather than defining it.
    local boxheight = background:getHeight()
    boxheight = 112
    local w, h = game:getDimensions()
    local boxwidth = w
    local boxtop = h - boxheight

    local BOXSCALE = 1  -- FIXME this was 2 for isaac
    local boxrepeatleft, boxrepeatright = 192, 224
    local boxquadl = love.graphics.newQuad(0, 0, boxrepeatleft, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadl, 0, boxtop, 0, BOXSCALE)
    local boxquadm = love.graphics.newQuad(boxrepeatleft, 0, boxrepeatright - boxrepeatleft, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadm, boxrepeatleft * BOXSCALE, boxtop, 0, math.floor(w / (boxrepeatright - boxrepeatleft)) + 1, BOXSCALE)
    local boxquadr = love.graphics.newQuad(boxrepeatright, 0, background:getWidth() - boxrepeatright, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadr, w - (background:getWidth() - boxrepeatright) * BOXSCALE, boxtop, 0, BOXSCALE)

    -- Print the text
    local max_lines = math.floor((boxheight - TEXT_MARGIN_Y * 2) / self.font_height)
    local texts = {}
    if self.state == 'menu' then
        -- FIXME i don't reeeally like this clumsy-ass two separate cases thing
        local lines = 0
        local m = self.menu_top
        local is_bottom = false
        for m = self.menu_top, #self.menu_items do
            local item = self.menu_items[m]
            local start_line = 1
            if m == self.menu_top then
                start_line = self.menu_top_line
            end
            for l = start_line, #item.lines do
                table.insert(texts, item.texts[l])
                if m == self.menu_cursor then
                    love.graphics.setColor(255, 255, 255, 64)
                    love.graphics.rectangle('fill', TEXT_MARGIN_X * 3/4, boxtop + TEXT_MARGIN_Y + self.font_height * lines, boxwidth - TEXT_MARGIN_X * 6/4, self.font_height)
                end
                if m == #self.menu_items and l == #item.lines then
                    is_bottom = true
                end
                lines = lines + 1
                if lines >= max_lines then
                    break
                end
            end
            if lines >= max_lines then
                break
            end
        end

        -- Draw little triangles to indicate scrollability
        -- FIXME magic numbers here...  should use sprites?  ugh
        love.graphics.setColor(255, 255, 255)
        if not (self.menu_top == 1 and self.menu_top_line == 1) then
            local x = TEXT_MARGIN_X
            local y = boxtop + TEXT_MARGIN_Y
            love.graphics.polygon('fill', x, y - 4, x + 2, y, x - 2, y)
        end
        if not is_bottom then
            local x = TEXT_MARGIN_X
            local y = h - TEXT_MARGIN_Y
            love.graphics.polygon('fill', x, y + 4, x + 2, y, x - 2, y)
        end
    else
        -- There may be more available lines than will fit in the textbox; if
        -- so, only show the last few lines
        -- FIXME should prompt to scroll when we hit the bottom, probably
        local first_line_offset = math.max(0, #self.phrase_texts - max_lines)
        for i = 1, max_lines do
            texts[i] = self.phrase_texts[i + first_line_offset]
        end

        -- Draw a small chevron if we're waiting
        -- FIXME more magic numbers
        if self.state == 'waiting' then
            local x = boxwidth - TEXT_MARGIN_X
            local y = math.floor(h - TEXT_MARGIN_Y * 1.5)
            love.graphics.setColor(self.phrase_speaker.color or self.default_color)
            love.graphics.polygon('fill', x, y + 8, x - 4, y, x + 4, y)
        end
    end

    local x, y = TEXT_MARGIN_X, boxtop + TEXT_MARGIN_Y
    for _, text in ipairs(texts) do
        -- Draw the text, twice: once for a drop shadow, then the text itself
        love.graphics.setColor(self.phrase_speaker.shadow or self.default_shadow)
        love.graphics.draw(text, x, y + 2)

        love.graphics.setColor(self.phrase_speaker.color or self.default_color)
        love.graphics.draw(text, x, y)

        y = y + self.font_height
    end

    -- Draw the speakers
    -- FIXME the draw order differs per run!
    love.graphics.setColor(255, 255, 255)
    for _, speaker in pairs(self.speakers) do
        local sprite = speaker.sprite
        if sprite then
            local sw, sh = sprite:getDimensions()
            local x
            if speaker.position == 'far left' then
                x = 1/8
            elseif speaker.position == 'left' then
                x = 1/4
            elseif speaker.position == 'right' then
                x = 3/4
            else
                print("unrecognized speaker position:", speaker.position)
                x = 0
            end
            local pos = Vector(math.floor((boxwidth - sw) * x + 0.5), boxtop - sh)
            sprite:draw_anchorless(pos)
        end
    end

    love.graphics.pop()
end

function DialogueScene:resize(w, h)
    -- FIXME adjust wrap width, reflow current text, etc.

    -- FIXME maybe should have a wrapperscene base class that automatically
    -- passes resize events along?
    if self.wrapped.resize then
        self.wrapped:resize(w, h)
    end
end

return DialogueScene
