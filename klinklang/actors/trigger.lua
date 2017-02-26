local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'


local TriggerZone = actors_base.BareActor:extend{
    name = 'trigger',
}

-- FIXME why don't i just take a shape?
function TriggerZone:init(pos, size, props)
    self.pos = pos
    self.shape = whammo_shapes.Box(pos.x, pos.y, size.x, size.y)

    self.props = props or {}
    if props then
        self.action = props.action
        self.activation = props.activation
    end
    if not self.action then
        self.action = 'submap'
    end
    if not self.activation then
        self.activation = 'use'
    end

    if self.activation == 'use' then
        self.is_usable = true
    end

    -- FIXME lol.  also shouldn't this be on_enter, really
    worldscene.collider:add(self.shape, self)
end

function TriggerZone:blocks(other, direction)
    return false
end

function TriggerZone:on_collide(activator)
    if activator.is_player and self.activation == 'touch' then
        self:execute_trigger(activator)
    end
end

function TriggerZone:on_use(activator)
    if activator.is_player and self.activation == 'use' then
        self:execute_trigger(activator)
    end
end

function TriggerZone:execute_trigger(activator)
    -- TODO turn these into, idk, closures or something interesting?
    if self.action == 'change map' then
        local map = game.resource_manager:load(self.props.map)
        worldscene:load_map(map, self.props.spot)
    elseif self.action == 'enter submap' then
        worldscene:enter_submap(self.props.submap)
    elseif self.action == 'leave submap' then
        worldscene:leave_submap()
    elseif self.action == 'broadcast' then
        for _, actor in ipairs(worldscene.actors) do
            if actor[self.props.message] then
                actor[self.props.message](actor, activator, self.props)
            end
        end
    end

    if self.props.once then
        worldscene:remove_actor(self)
    end
end


return TriggerZone
