local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'


local NORTH = Vector(0, -16)
local SOUTH = Vector(0, 16)
local EAST = Vector(16, 0)
local WEST = Vector(-16, 0)

-- TODO i'd like to improve "powered" to a broader understanding of all current
-- inputs, so other stuff can be sent over wires.  but at the same time, there
-- should always be a simple prop i can check to know if i have any input at
-- all
local Wirable = actors_base.Actor:extend{
    __name = 'Wirable',
    nodes = {},
    powered = 0,
    can_emit = true,
    can_receive = true,
    z = 2000,  -- in front of the player
}

function Wirable:init(...)
    actors_base.Actor.init(self, ...)

    self.live_connections = setmetatable({}, { __mode = 'k' })
end

function Wirable:on_enter()
    local orig = self.powered

    -- FIXME get this stuff from the physics engine (but wait, how, if these lot don't have collision??)
    -- ...and more importantly, how would that interact with stuff like the pressure plate that only conducts through a single edge?
    -- FIXME this, seems, overly complicated
    local nodes = {}
    for _, offset in ipairs(self.nodes) do
        table.insert(nodes, self.pos + offset)
    end
    for _, actor in ipairs(worldscene.actors) do
        if actor ~= self and actor._receive_pulse then
            local is_connection = false
            for _, offset in ipairs(actor.nodes) do
                local their_node = actor.pos + offset
                for _, my_node in ipairs(nodes) do
                    if my_node == their_node then
                        is_connection = true
                        break
                    end
                    if is_connection then
                        break
                    end
                end
            end
            if is_connection then
                -- FIXME seems invasive
                if actor.can_emit and self.can_receive then
                    if actor.powered > 0 then
                        self.live_connections[actor] = -1
                        actor.live_connections[self] = 1
                        self.powered = self.powered + 1
                    else
                        self.live_connections[actor] = 0
                        actor.live_connections[self] = 0
                    end
                end
                if self.can_emit and actor.can_receive then
                    local powered = self.powered > 0
                    if self.live_connections[actor] == -1 then
                        -- Already powering us; do nothing!
                    elseif powered then
                        actor:_receive_pulse(true, self)
                        self.live_connections[actor] = 1
                    else
                        self.live_connections[actor] = 0
                        actor.live_connections[self] = 0
                    end
                end
            end
        end
    end

    self:_emit_pulse(self.powered > 0)
    self:on_power_change(self.powered > 0)
end

function Wirable:on_leave()
    self:_emit_pulse(false)
    -- FIXME this seems, idk, kinda silly
    for connection, state in pairs(self.live_connections) do
        connection.live_connections[self] = nil
        if state == -1 then
            self.powered = self.powered - 1
        end
    end
    self.live_connections = {}
end

function Wirable:_emit_pulse(value)
    if not self.can_emit then
        return
    end
    for connection, state in pairs(self.live_connections) do
        if value == true and state == 0 then
            self.live_connections[connection] = 1
            connection:_receive_pulse(value, self)
        elseif value == false and state == 1 then
            self.live_connections[connection] = 0
            connection:_receive_pulse(value, self)
        end
    end
end

function Wirable:_receive_pulse(value, source)
    if not self.can_receive then
        return
    end
    if self.live_connections[source] == 1 then
        return
    end

    local orig = self.powered
    if value == true then
        if self.live_connections[source] ~= -1 then
            self.powered = self.powered + 1
        end
        self.live_connections[source] = -1
    else
        if self.live_connections[source] == -1 then
            self.powered = self.powered - 1
        end
        self.live_connections[source] = 0
    end

    if orig == 0 and self.powered > 0 then
        self._pending_pulse = true
        self:on_power_change(true)
    elseif orig > 0 and self.powered == 0 then
        self._pending_pulse = false
        self:on_power_change(false)
    elseif not value and orig > 0 and self.powered > 0 then
        -- They lost power, but we still have some, so re-emit our current
        -- pulse next frame.
        -- This can happen if a circuit with a loop is reconfigured
        self._pending_pulse = true
    end
end

function Wirable:on_power_change(active)
    if active then
        self.sprite:set_pose('on')
    else
        self.sprite:set_pose('off')
    end
end

function Wirable:update(dt)
    actors_base.Actor.update(self, dt)

    -- FIXME hm, this carries pulses in frames rather than in absolute time
    if self._pending_pulse ~= nil then
        self:_emit_pulse(self._pending_pulse)
        self._pending_pulse = nil
    end
end

function Wirable:draw()
    actors_base.Actor.draw(self)

    --[[
    love.graphics.setColor(255, 0, 255)
    for _, node in ipairs(self.nodes) do
        local xy = self.pos + node
        love.graphics.circle('fill', xy.x, xy.y, 2)
    end
    love.graphics.setColor(255, 255, 255)

    if self.powered > 0 and self.shape then
        love.graphics.setColor(255, 255, 0, 128)
        self.shape:draw('fill')
    end
    for connection, state in pairs(self.live_connections) do
        local direction = connection.pos - self.pos
        if state == -1 then
            love.graphics.setColor(0, 255, 0)
        elseif state == 1 then
            love.graphics.setColor(255, 0, 0)
        else
            love.graphics.setColor(255, 255, 0)
        end
        local midpoint = self.pos + direction / 4
        local perp = direction:perpendicular() / 4
        love.graphics.line(self.pos.x, self.pos.y, midpoint.x, midpoint.y)
    end
    love.graphics.setColor(255, 255, 255)
    ]]
end
            


local Emitter = Wirable:extend{
    name = 'emitter',
    sprite_name = 'emitter',

    nodes = {Vector(0, 8)},
    powered = 1,
    can_receive = false,
}


local WireNS = Wirable:extend{
    name = 'wire ns',
    sprite_name = 'wire ns',

    nodes = {NORTH, SOUTH},
}

local WireNE = Wirable:extend{
    name = 'wire ne',
    sprite_name = 'wire ne',

    nodes = {NORTH, EAST},
}

local WireNW = Wirable:extend{
    name = 'wire nw',
    sprite_name = 'wire nw',

    nodes = {NORTH, WEST},
}

local WireSW = Wirable:extend{
    name = 'wire sw',
    sprite_name = 'wire sw',

    nodes = {SOUTH, WEST},
}

local WireSE = Wirable:extend{
    name = 'wire se',
    sprite_name = 'wire se',

    nodes = {SOUTH, EAST},
}

local WireEW = Wirable:extend{
    name = 'wire ew',
    sprite_name = 'wire ew',

    nodes = {EAST, WEST},
}

local WireNEW = Wirable:extend{
    name = 'wire new',
    sprite_name = 'wire new',

    nodes = {NORTH, EAST, WEST},
}

local WireNSW = Wirable:extend{
    name = 'wire nsw',
    sprite_name = 'wire nsw',

    nodes = {NORTH, SOUTH, WEST},
}

local Bulb = Wirable:extend{
    name = 'bulb',
    sprite_name = 'bulb',

    nodes = {Vector(0, 8)},
    can_emit = false,
}

function Bulb:on_power_change(active)
    if active then
        self.sprite:set_pose('on')
    else
        self.sprite:set_pose('off')
    end
end


local WirePlugNS = Wirable:extend{
    name = 'wire plug ns',
    sprite_name = 'wire plug ns',

    nodes = {NORTH, SOUTH},
}

local WirePlugEW = Wirable:extend{
    name = 'wire plug ew',
    sprite_name = 'wire plug ew',

    nodes = {EAST, WEST},
}

local WirePlugNE = Wirable:extend{
    name = 'wire plug ne',
    sprite_name = 'wire plug ne',

    nodes = {NORTH, EAST},
}

local WirePlugNW = Wirable:extend{
    name = 'wire plug nw',
    sprite_name = 'wire plug nw',

    nodes = {NORTH, WEST},
}

local WirePlugSE = Wirable:extend{
    name = 'wire plug se',
    sprite_name = 'wire plug se',

    nodes = {SOUTH, EAST},
}

local WireSocket = actors_base.Actor:extend{
    name = 'wire socket',
    sprite_name = 'wire socket',
    z = 1999,  -- in front of the player but behind its wire

    is_usable = true,
}

function WireSocket:init(pos, props)
    WireSocket.__super.init(self, pos)
    if props then
        self.spawn_with = props['contains plug']
    end
end

function WireSocket:blocks()
    -- FIXME i'd like this to be blocking, but then you can't use it, because you use things you /overlap/
    return false
end

function WireSocket:on_enter()
    if self.spawn_with then
        local plugtype = actors_base.Actor:get_named_type(self.spawn_with)
        local plug = plugtype(self.pos)
        self.ptrs.plug = plug
        worldscene:add_actor(plug)
    end
end

-- TODO it would be nice if we could be notified when our plug is removed
function WireSocket:on_use(activator)
    -- TODO game-specific
end


local Bolt = Wirable:extend{
    name = 'bolt',
    sprite_name = 'bolt',
    z = -1,

    nodes = {NORTH, SOUTH, EAST, WEST},
}

function Bolt:blocks()
    return self.powered == 0
end

function Bolt:on_power_change(active)
    if active then
        self.sprite:set_pose('open')
    else
        self.sprite:set_pose('closed')
    end
end


local SlidingDoor = Wirable:extend{
    name = 'sliding door',
    sprite_name = 'sliding door',

    --nodes = {Vector(0, -64)},
    -- FIXME need to turn the door's roof into its own object
    nodes = {Vector(-8, -64 - 16 * 8)},
    can_emit = false,
}

function SlidingDoor:blocks()
    return true
end

function SlidingDoor:on_power_change(active)
    if active then
        self.sprite:set_pose('opening')
        self.sprite:update(0)
        local oldonloop = self.sprite.anim.onLoop
        self.sprite.anim.onLoop = function()
            self.sprite:set_pose('open')
            self.sprite:update(0)
            local shape = self.sprite.shape:clone()
            shape:move_to(self.pos:unpack())
            self:set_shape(shape)
        end
    end
end


return {
    Wirable = Wirable,
    Bulb = Bulb,
    WireNS = WireNS,
    WireNE = WireNE,
    WireNW = WireNW,
    WireEW = WireEW,
    Emitter = Emitter,
    WirePlugNE = WirePlugNE,
    WireSocket = WireSocket,
}
