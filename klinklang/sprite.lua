local anim8 = require 'vendor.anim8'

local Object = require 'klinklang.object'

--------------------------------------------------------------------------------
-- SpriteSet
-- Contains a number of 'poses', each of which is an anim8 animation.  Can
-- switch between them and draw with a simplified API.

local Sprite
local SpriteSet = Object:extend{
    _all_sprites = {},
}

function SpriteSet:init(name, image)
    self.name = name
    self.poses = {}
    self.default_pose = nil
    self.image = image

    SpriteSet._all_sprites[name] = self
end

function SpriteSet:add(pose_name, anchor, shape, frames, durations, onloop, flipped)
    assert(not self.poses[pose_name], ("Pose %s already exists"):format(pose_name))

    -- FIXME this is pretty hokey and seems really specific to platformers
    local anim = anim8.newAnimation(frames, durations, onloop)
    local flipped_shape
    if shape then
        flipped_shape = shape:flipx(0)
    end
    local normal_data = {
        animation = anim,
        shape = shape,
        anchor = anchor,
    }
    local flipped_data = {
        animation = anim:clone():flipH(),
        shape = flipped_shape,
        -- FIXME probably...  not right
        anchor = anchor,
    }
    if flipped then
        self.poses[pose_name] = {
            left = normal_data,
            right = flipped_data,
        }
    else
        self.poses[pose_name] = {
            left = flipped_data,
            right = normal_data,
        }
    end
    if not self.default_pose then
        self.default_pose = pose_name
    end
end

-- A Sprite is a definition; call this to get an instance with state, which can
-- draw itself and remember its current pose
function SpriteSet:instantiate()
    return Sprite(self)
end

Sprite = Object:extend{}

function Sprite:init(spriteset)
    self.spriteset = spriteset
    self.scale = 1
    self.pose = nil
    self.facing = 'right'
    self._pending_pose = nil
    self.anim = nil
    -- TODO this doesn't check that the default pose exists
    self:_set_pose(spriteset.default_pose)
end

-- Schedule the given pose to replace the current pose on the next update()
-- call.  (This way, calling set_pose() followed by update() doesn't skip the
-- first frame of the new pose.)
-- Changing to the current pose is a no-op.
function Sprite:set_pose(pose)
    if pose == (self._pending_pose or self.pose) then
    elseif self.spriteset.poses[pose] then
        self._pending_pose = pose
    else
        local all_poses = {}
        for pose_name in pairs(self.spriteset.poses) do
            table.insert(all_poses, pose_name)
        end
        error(("No such pose %s (available: %s)"):format(pose, table.concat(all_poses, ", ")))
    end
end

function Sprite:_set_pose(pose)
    -- Internal method that actually changes the pose.  Doesn't check that the
    -- pose exists.
    self.pose = pose
    local data = self.spriteset.poses[pose][self.facing]
    self.anim = data.animation:clone()
    self.anchor = data.anchor
    self.shape = data.shape
    self._pending_pose = nil
end

function Sprite:set_facing_right(facing_right)
    local new_facing
    if facing_right then
        new_facing = 'right'
    else
        new_facing = 'left'
    end

    if new_facing ~= self.facing then
        self.facing = new_facing
        -- Restart the animation if we're changing direction
        if self._pending_pose == nil then
            self._pending_pose = self.pose
        end
    end
end

function Sprite:set_scale(scale)
    self.scale = scale
end

function Sprite:getDimensions()
    local w, h = self.anim:getDimensions()
    return w * self.scale, h * self.scale
end

function Sprite:update(dt)
    if self._pending_pose then
        self:_set_pose(self._pending_pose)
    else
        self.anim:update(dt)
    end
end

function Sprite:draw_at(point)
    -- TODO hm, how do i auto-batch?  shame there's nothing for doing that
    -- built in?  seems an obvious thing
    self.anim:draw(
        self.spriteset.image,
        math.floor(point.x - self.anchor.x),
        math.floor(point.y - self.anchor.y),
        0, self.scale, self.scale)
end


return SpriteSet
