local Vector = require 'vendor.hump.vector'

local Object = require 'klinklang.object'
local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local whammo_shapes = require 'klinklang.whammo.shapes'


local GenericSlidingDoor = actors_base.Actor:extend{
    -- Configuration
    door_width = 16,

    -- State
    door_height = 0,
    busy = false,
}

function GenericSlidingDoor:init(...)
    GenericSlidingDoor.__super.init(self, ...)

    self.sprite:set_pose('middle')

    -- TODO this would be nice
    --[[
    self.sfx = game.resource_manager:get('assets/sounds/stonegrind.ogg'):clone()
    self.sfx:setVolume(0.75)
    self.sfx:setLooping(true)
    self.sfx:setPosition(self.pos.x, self.pos.y, 0)
    self.sfx:setAttenuationDistances(game.TILE_SIZE * 4, game.TILE_SIZE * 32)
    ]]
end

-- FIXME what happens if you stick a rune in an open doorway?
function GenericSlidingDoor:on_enter()
    -- FIXME this "ray" should really have a /width/
    local impact, impactdist = worldscene.collider:fire_ray(
        self.pos,
        Vector(0, 1),
        function (actor)
            return actor == self
        end)
    -- FIXME if the ray doesn't hit anything, it returns...  infinity.  also it
    -- doesn't actually walk the whole blockmap, oops!
    if impactdist == math.huge then
        impactdist = 0
    end
    self:set_shape(whammo_shapes.Box(-12, 0, 24, impactdist))
    self.door_height = impactdist
end

function GenericSlidingDoor:on_leave()
    --self.sfx:stop()
end

function GenericSlidingDoor:blocks()
    return true
end

function GenericSlidingDoor:update(dt)
end

-- FIXME this makes some assumptions about anchors that i'm pretty sure could be either less necessary or more meaningful
function GenericSlidingDoor:draw()
    local pt = self.pos - self.sprite.anchor
    love.graphics.push('all')
    -- FIXME maybe worldscene needs a helper for this
    -- FIXME lot of hardcoded numbers here
    love.graphics.setScissor(pt.x - worldscene.camera.x, pt.y - worldscene.camera.y, 32, self.door_height)
    local height = self.door_height + (-self.door_height) % 32
    local top = pt.y - (-self.door_height) % 32
    local bottom = pt.y + self.door_height, 32
    for y = top, bottom, 32 do
        local sprite = self.sprite.anim
        if y == bottom - 32 then
            -- FIXME invasive...
            sprite = self.sprite.spriteset.poses['end'].right.animation
        end
        sprite:draw(self.sprite.spriteset.image, math.floor(pt.x), math.floor(y))
    end
    love.graphics.pop()
end

function GenericSlidingDoor:open()
    if self.busy then
        return
    end
    self.busy = true
    if self.door_height <= 32 then
        return
    end

    -- FIXME i would like some little dust clouds
    -- FIXME grinding noise
    -- FIXME what happens if the door hits something?
    local height = self.door_height
    local time = height / 30
    worldscene.fluct:to(self, time, { door_height = 32 })
        :ease('linear')
        -- TODO would be nice to build the shape from individual sprite collisions
        :onupdate(function() self:set_shape(whammo_shapes.Box(-12, 0, 24, self.door_height)) end)
        --:onstart(function() self.sfx:play() end)
        --:oncomplete(function() self.sfx:stop() end)
    -- FIXME closing should be configurable
    --[[
        :after(time, { door_height = height })
        :delay(4)
        :ease('linear')
        :onupdate(function() self:set_shape(whammo_shapes.Box(-12, 0, 24, self.door_height)) end)
        :oncomplete(function() self.busy = false end)
        --:onstart(function() self.sfx:play() end)
        --:oncomplete(function() self.sfx:stop() end)
    ]]
end

function GenericSlidingDoor:open_instant()
    if self.busy then
        -- FIXME this should cancel an ongoing open(), surely
        return
    end
    if self.door_height <= 32 then
        return
    end

    self.door_height = 32
    self:set_shape(whammo_shapes.Box(-12, 0, 24, self.door_height))
end



local GenericSlidingDoorShutter = actors_base.Actor:extend{
    -- Configuration
    door_type = nil,
}

function GenericSlidingDoorShutter:init(...)
    actors_base.Actor.init(self, ...)
end

function GenericSlidingDoorShutter:on_enter()
    local door = self.door_type(self.pos)
    self.ptrs.door = door
    worldscene:add_actor(door)
end

function GenericSlidingDoorShutter:blocks(actor, dir)
    return true
end

function GenericSlidingDoorShutter:open()
    -- FIXME support this, but also turn it off when the door is off
    --self.sprite:set_pose('active')
    self.ptrs.door:open()
end

function GenericSlidingDoorShutter:open_instant()
    self.ptrs.door:open_instant()
end


local LadderZone = actors_base.BareActor:extend{
    is_climbable = true,
}

function LadderZone:init(pos, shape)
    self.shape = shape
    LadderZone.__super.init(self, pos)
end


return {
    GenericSlidingDoor = GenericSlidingDoor,
    GenericSlidingDoorShutter = GenericSlidingDoorShutter,
    GenericLadder = GenericLadder,
    LadderZone = LadderZone,
}
