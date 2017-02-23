local anim8 = require 'vendor.anim8'
local Vector = require 'vendor.hump.vector'

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

-- Adds a new pose, which may be animated.  All frames are presumed to be the
-- same size, and all frames of all poses must be part of the same image.
-- Adding a new pose with the same name is an error, EXCEPT in the case of
-- adding a left view to a pose that only has a right view defined (or vice
-- versa).
-- Arguments:
--   name: The name of the pose, used with Sprite:set_pose.
--   anchor: When Sprite:draw_at is called, the sprite will be positioned such
--      that this point (a Vector) on the sprite appears at the desired
--      position.
--   shape: An optional collision shape.  Somewhat clumsy at the moment.
--   frames: A list of Quads defining how to cut out each frame.
--   durations: Frame durations, in seconds.  Passed directly to anim8.
--   onloop: Behavior for the end of the loop.  Passed directly to anim8.
--   flipped: If true, the frames face to the left, and will be flipped when
--      the sprite faces right (rather than the other way around).
--   leftwards: If true, the pose is taken to be asymmetrical, and the given
--      frames are used as the left-facing view.  To create a fully
--      asymmetrical pose, call add_pose twice: once with leftwards false, once
--      with it true.  Note that the actual frames are still assumed to face
--      right, unless flipped is true.
function SpriteSet:add_pose(args)
    local pose_name = args.name
    local anchor = args.anchor
    local shape = args.shape
    local frames = args.frames
    local durations = args.durations
    local onloop = args.onloop
    local flipped = args.flipped
    local leftwards = args.leftwards

    local pose
    if self.poses[pose_name] then
        pose = self.poses[pose_name]
        if pose[leftwards and 'left' or 'right'].explicit then
            error(("Pose %s already exists for sprite %s"):format(pose_name, self.name))
        end
    else
        pose = {}
        self.poses[pose_name] = pose
    end

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
    -- FIXME this assumes the frames are all the same size; either avoid
    -- requiring that (which may be impossible) or explicitly enforce it
    local _, _, w, _ = frames[1]:getViewport()
    local flipped_data = {
        animation = anim:clone():flipH(),
        shape = flipped_shape,
        anchor = Vector(w - anchor.x, anchor.y),
    }

    -- Handle flippedness
    local left_data, right_data
    if flipped then
        left_data, right_data = normal_data, flipped_data
    else
        left_data, right_data = flipped_data, normal_data
    end

    -- Handle asymmetry
    if leftwards then
        left_data.explicit = true
    else
        right_data.explicit = true
    end

    -- Assign the pose facings
    if not pose.left or not pose.left.explicit then
        pose.left = left_data
    end
    if not pose.right or not pose.right.explicit then
        pose.right = right_data
    end

    if not self.default_pose then
        self.default_pose = pose_name
    end
end

-- A Sprite is a definition; call this to get an instance with state, which can
-- draw itself and remember its current pose
function SpriteSet:instantiate(...)
    return Sprite(self, ...)
end

Sprite = Object:extend{}

function Sprite:init(spriteset, pose_name, facing)
    self.spriteset = spriteset
    self.scale = 1
    self.pose = nil
    self.facing = facing or 'right'
    self._pending_pose = nil
    self._pending_callback = nil
    self.anim = nil
    -- TODO this doesn't check that the given pose exists
    self:_set_pose(pose_name or spriteset.default_pose)
end

-- Schedule the given pose to replace the current pose on the next update()
-- call.  (This way, calling set_pose() followed by update() doesn't skip the
-- first frame of the new pose.)
-- If given, the callback will be called when the animation loops.
function Sprite:set_pose(pose, callback)
    if pose == self._pending_pose then
        -- FIXME this might clobber an existing callback, Ugh.  (or is that a feature?)
        self._pending_callback = callback
    elseif pose == self.pose then
        if callback then
            self:_add_loop_callback(callback)
        end
    elseif self.spriteset.poses[pose] then
        self._pending_pose = pose
        self._pending_callback = callback
    else
        local all_poses = {}
        for pose_name in pairs(self.spriteset.poses) do
            table.insert(all_poses, pose_name)
        end
        table.sort(all_poses)
        error(("No such pose '%s' for %s (available: %s)"):format(pose, self.spriteset.name, table.concat(all_poses, ", ")))
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

-- Set a function to be called whenever the current pose reaches its end.
-- If the pose is changed before that happens, the callback is abandoned.
function Sprite:_add_loop_callback(callback)
    local oldonloop = self.anim.onLoop
    self.anim.onLoop = function(anim, ...)
        callback(anim, ...)

        if type(oldonloop) == 'function' then
            oldonloop(anim, ...)
        elseif oldonloop then
            anim[oldonloop](anim, ...)
        end
    end
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
        if self._pending_callback then
            self:_add_loop_callback(self._pending_callback)
            self._pending_callback = nil
        end
    else
        self.anim:update(dt)
    end
end

function Sprite:draw_at(point)
    -- TODO hm, how do i auto-batch?  shame there's nothing for doing that
    -- built in?  seems an obvious thing
    self.anim:draw(
        self.spriteset.image,
        math.floor(point.x - self.anchor.x * self.scale + 0.5),
        math.floor(point.y - self.anchor.y * self.scale + 0.5),
        0, self.scale, self.scale)
end

function Sprite:draw_anchorless(point)
    self.anim:draw(
        self.spriteset.image,
        math.floor(point.x + 0.5),
        math.floor(point.y + 0.5),
        0, self.scale, self.scale)
end


return SpriteSet
