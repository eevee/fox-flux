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

-- FIXME if you're exactly in a corner and try to move diagonally, the
-- resulting clock will only block one direction, sigh
function Collider:slide(shape, attempted, pass_callback, xxx_no_slide)
    --print()
    --print(("=== SLIDE: %s ==="):format(attempted))
    local successful = Vector(0, 0)
    local hits = {}  -- set of objects we ultimately bump into
    local lastclock = util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
    local stuckcounter = 0

    -- TODO i wonder if this should just do a single move and leave the sliding
    -- and looping up to the caller?
    while true do
        --print("--- STARTING ROUND; ATTEMPTING TO MOVE", attempted)
        local collisions = {}
        local neighbors = self.blockmap:neighbors(shape, attempted:unpack())
        for neighbor in pairs(neighbors) do
            local collision = shape:slide_towards(neighbor, attempted)
            if collision then
                --print(("< got move %f = %s, touchtype %d, clock %s"):format(collision.amount, collision.movement, collision.touchtype, collision.clock))
                collision.shape = neighbor
                collision.attempted = attempted
                table.insert(collisions, collision)
            end
        end

        -- Look through the objects we'll hit, in the order we'll /touch/ them,
        -- and stop at the first that blocks us
        table.sort(collisions, _collision_sort)
        local allowed_amount
        -- Intersection of all the "clocks" (sets of allowable slide angles) we find
        local combined_clock = util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
        local combined_clock2 = util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
        for i, collision in ipairs(collisions) do
            --print("checking collision...", collision.movement, collision.amount, "at", collision.shape:bbox())
            -- If we've already found something that blocks us, and this
            -- collision requires moving further, then stop here.  This allows
            -- for ties
            if allowed_amount ~= nil and allowed_amount < collision.amount then
                break
            end

            -- Check if the other shape actually blocks us
            local passable = pass_callback and pass_callback(collision)
            local update_lastclock = true
            if passable == 'retry' then
                -- Special case: the other object just moved, so keep moving
                -- and re-evaluate when we hit it again.  Useful for pushing.
                if hits[collision.shape] == nil then
                    local new_collision = shape:slide_towards(collision.shape, attempted)
                    if new_collision then
                        new_collision.shape = collision.shape
                        new_collision.attempted = attempted
                        for j = i + 1, #collisions + 1 do
                            if j > #collisions or not _collision_sort(collisions[j], new_collision) then
                                table.insert(collisions, j, new_collision)
                                break
                            end
                        end
                    end
                else
                    -- We're only willing to try once!  If we're asked to try a
                    -- second time, assume the object is stuck, and we in turn
                    -- are stuck on it.
                    print("!!! OH NO !!! GOT RETRY TWICE")
                    passable = false
                end
            -- Extra special case: we're blocked, but we still want to be able
            -- to /try/ to move in this direction, so we still do a slide but
            -- don't tell the caller about it.  Used /after/ pushing a heavy
            -- object, so the pusher's velocity isn't cut.
            elseif passable == 'trim' then
                passable = false
                update_lastclock = false
            end

            if not passable then
                -- We're blocked, so restrict our slide angle
                combined_clock:intersect(collision.clock)
                if update_lastclock then
                    combined_clock2:intersect(collision.clock)
                end

                -- If we're hitting the object and it's not passable, stop here
                if allowed_amount == nil and collision.touchtype > 0 then
                    allowed_amount = collision.amount
                    print("< found first collision:", collision.movement, "amount:", collision.amount, self:get_owner(collision.shape))
                    for k, v in pairs(collision) do print(k, v) end
                    for normal in pairs(collision.normals) do print("normal:", normal) end
                end
            end

            -- Log the last contact with each shape
            collision.passable = passable
            -- FIXME this ends up returning normals that may no longer apply...
            hits[collision.shape] = collision
        end

        -- Automatically break if we don't move for three iterations -- not
        -- moving once is okay because we might slide, but three indicates a
        -- bad loop somewhere
        -- TODO would be nice to avoid this entirely!  it happens, e.g., at the
        -- bottom of the slopetest ramp: position       (606.5,638.5)   velocity        (61.736288265774419415,121.03382860727833759)   movement        (1.5,2.5)
        if allowed_amount == 0 then
            stuckcounter = stuckcounter + 1
            if stuckcounter >= 3 then
                print("!!!  BREAKING OUT OF LOOP BECAUSE WE'RE STUCK, OOPS")
                break
            end
        else
            stuckcounter = 0
        end

        -- Track the last clock, so we can tell the caller which directions
        -- they're still blocked in after moving
        lastclock = combined_clock2

        -- FIXME this seems like a poor way to get at this logic from outside
        if xxx_no_slide then
            if allowed_amount ~= nil then
                return allowed_amount * attempted, hits, lastclock
            else
                return attempted, hits, lastclock
            end
        end

        if allowed_amount == nil or allowed_amount >= 1 then
            -- We don't hit anything this time!  Apply the remaining unopposed
            -- movement and stop looping
            --print("moving by leftovers", attempted)
            shape:move(attempted:unpack())
            successful = successful + attempted
            break
        end

        -- Perform the actual move; we have to move ourselves so we can correctly handle the next iteration
        local allowed_movement = allowed_amount * attempted
        --print("moving by", allowed_movement)
        shape:move(allowed_movement:unpack())
        successful = successful + allowed_movement

        -- Slide along the extreme that's closest to the direction of movement
        local slide = combined_clock:closest_extreme(attempted)
        if not slide then
            break
        end
        local remaining = attempted - allowed_movement
        if remaining * slide < 0 then
            -- Can't slide anywhere near the direction of movement, so we
            -- have to stop here
            break
        end
        attempted = remaining:projectOn(slide)

        -- FIXME these values are completely arbitrary and i cannot justify them
        if math.abs(attempted.x) < 1/16 and math.abs(attempted.y) < 1/16 then
            break
        end
    end

    -- FIXME i would very much like to round movement to the nearest pixel, but
    -- doing so requires finding a rounding direction that's not already
    -- blocked, and at the moment i seem to have much better luck doing no
    -- rounding whatsoever

    --print("TOTAL MOVEMENT:", successful)
    return successful, hits, lastclock
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
