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

    if props then
        self.action = props.action
    end
    if not self.action then
        self.action = 'submap'
    end

    -- FIXME should probably have a trigger...  mode
    if self.action == 'submap' then
        self.is_usable = true
    end

    -- FIXME lol.  also shouldn't this be on_enter, really
    worldscene.collider:add(self.shape, self)
end

function TriggerZone:blocks(other, direction)
    return false
end

function TriggerZone:on_use(activator)
    -- FIXME my map has props for this stuff, which i should probably be using here
    if self.action == 'submap' then
        if worldscene.submap then
            worldscene:leave_submap()
        else
            worldscene:enter_submap('inside house 1')
        end
    end
end


return TriggerZone
