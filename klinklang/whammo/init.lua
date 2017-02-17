local Vector = require 'vendor.hump.vector'

local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local Blockmap = require 'klinklang.whammo.blockmap'
local shapes = require 'klinklang.whammo.shapes'

local Collider = Object:extend{
    _NOTHING = {},
}

function Collider:init(blocksize)
    -- Weak map of shapes to their "owners", where "owner" can mean anything
    -- and is the special value _NOTHING to mean no owner
    self.shapes = setmetatable({}, {__mode = 'k'})
    self.blockmap = Blockmap(blocksize)
end

function Collider:add(shape, owner)
    if owner == nil then
        owner = self._NOTHING
    end
    self.blockmap:add(shape)
    self.shapes[shape] = owner
end

function Collider:remove(shape)
    if self.shapes[shape] ~= nil then
        self.blockmap:remove(shape)
        self.shapes[shape] = nil
    end
end

function Collider:get_owner(shape)
    owner = self.shapes[shape]
    if owner == self._NOTHING then
        owner = nil
    end
    return owner
end


-- Sort collisions in the order we'll come into contact with them (whether or
-- not we'll actually hit them as a result)
local function _collision_sort(a, b)
    if a.touchdist == b.touchdist then
        return a.touchtype < b.touchtype
    end
    return a.touchdist < b.touchdist
end

-- FIXME consider renaming this and the other method to "sweep"
function Collider:slide(shape, attempted, pass_callback)
    local hits = {}
    local collisions = {}
    local neighbors = self.blockmap:neighbors(shape, attempted:unpack())
    for neighbor in pairs(neighbors) do
        local collision = shape:slide_towards(neighbor, attempted)
        if collision then
            --print(("< got move %f = %s, touchtype %d, clock %s"):format(collision.amount, collision.movement, collision.touchtype, collision.clock))
            collision.shape = neighbor
            table.insert(collisions, collision)
        end
    end

    -- Look through the objects we'll hit, in the order we'll /touch/ them,
    -- and stop at the first that blocks us
    table.sort(collisions, _collision_sort)
    local allowed_amount
    for i, collision in ipairs(collisions) do
        collision.attempted = attempted

        --print("checking collision...", collision.movement, collision.amount, "at", collision.shape:bbox())
        -- If we've already found something that blocks us, and this
        -- collision requires moving further, then stop here.  This allows
        -- for ties
        if allowed_amount ~= nil and allowed_amount < collision.amount then
            break
        end

        -- Check if the other shape actually blocks us
        local passable = pass_callback and pass_callback(collision)
        if passable == 'retry' then
            -- Special case: the other object just moved, so keep moving
            -- and re-evaluate when we hit it again.  Useful for pushing.
            if i > 1 and collisions[i - 1].shape == collision.shape then
                -- To avoid loops, don't retry a shape twice in a row
                passable = false
            else
                local new_collision = shape:slide_towards(collision.shape, attempted)
                if new_collision then
                    new_collision.shape = collision.shape
                    for j = i + 1, #collisions + 1 do
                        if j > #collisions or not _collision_sort(collisions[j], new_collision) then
                            table.insert(collisions, j, new_collision)
                            break
                        end
                    end
                end
            end
        end

        -- If we're hitting the object and it's not passable, stop here
        if allowed_amount == nil and not passable and collision.touchtype > 0 then
            allowed_amount = collision.amount
            --print("< found first collision:", collision.movement, "amount:", collision.amount, self:get_owner(collision.shape))
        end

        -- Log the last contact with each shape
        collision.passable = passable
        hits[collision.shape] = collision
    end

    if allowed_amount == nil or allowed_amount >= 1 then
        -- We don't hit anything this time!  Apply the remaining unopposed
        -- movement
        return attempted, hits
    else
        return attempted * allowed_amount, hits
    end
end

function Collider:fire_ray(start, direction, collision_check_func)
    local perp = direction:perpendicular()
    local startdot = direction * start
    local startperpdot = perp * start
    -- TODO this returns EVERY BLOCK along the ray which seems unlikely to be
    -- useful
    local nearest, nearestpt = math.huge, nil
    local neighbors = self.blockmap:neighbors_along_ray(
        start.x, start.y, direction.x, direction.y)
    local _hits = {}
    for neighbor in pairs(neighbors) do
        if not collision_check_func or not collision_check_func(self:get_owner(neighbor)) then
            -- TODO i can do this by projecting the whole shape onto the ray, i think??  that gives me distance (along the ray, anyway), then i just need to check that it actually hits, somehow.  project onto perpendicular?
            local min, max, minpt, maxpt = neighbor:project_onto_axis(perp)
            if min <= startperpdot and startperpdot <= max then
                --_hits[neighbor] = 1
                local min, max, minpt, maxpt = neighbor:project_onto_axis(direction)
                if min > startdot and min < nearest then
                    _hits = {[neighbor] = 1}
                    nearest = min
                    nearestpt = minpt
                elseif max > startdot and max < nearest then
                    _hits = {[neighbor] = 1}
                    nearest = max
                    nearestpt = maxpt
                end
            end
        end
    end

    return nearestpt, nearest - startdot
end

return {
    Collider = Collider,
}
