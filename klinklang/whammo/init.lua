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


-- FIXME if you're exactly in a corner and try to move diagonally, the
-- resulting clock will only block one direction, sigh
function Collider:slide(shape, dx, dy, xxx_no_slide)
    --print()
    local attempted = Vector(dx, dy)
    local successful = Vector(0, 0)
    local allhits = {}  -- set of objects we ultimately bump into
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
                table.insert(collisions, collision)
            end
        end

        -- Look through the objects we'll hit, in the order we'll /touch/ them,
        -- and stop at the first that blocks us
        table.sort(collisions, function(a, b)
            if a.touchdist == b.touchdist then
                return a.touchtype < b.touchtype
            end
            return a.touchdist < b.touchdist
        end)
        local allowed_amount
        -- Intersection of all the "clocks" (sets of allowable slide angles) we find
        local combined_clock = util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
        for _, collision in ipairs(collisions) do
            --print("checking collision...", collision.movement, collision.amount, "at", collision.shape:bbox())
            -- If we've already found something that blocks us, and this
            -- collision requires moving further, then stop here.  This allows
            -- for ties
            if allowed_amount ~= nil and allowed_amount < collision.amount then
                break
            end

            -- Check whether we can move through this object
            local is_passable = false
            -- One-way platforms only block us in downwards directions.
            -- But the simple approach presents a problem.  If we're standing
            -- on a platform, the first round will slide us against it (making
            -- our y movement zero) and the second round will then catch the
            -- platform again, see y == 0, and think it no longer blocks us.
            -- We won't fall through it, but the actor code will think we're
            -- suspended in midair.  So we have to check whether we've already
            -- collided with this platform during a previous round.
            -- Also, if we happen to be exactly on the platform but moving away
            -- from it, that will count as a touch and update our collision
            -- clock, which makes actor code think we're standing on ground.
            -- So a slide always counts as passable, too.
            -- FIXME that above bit doesn't sit right; if we want to announce
            -- slides and update the clock for them, they should be important
            -- for one-way platforms too.  if not, why have them at all?
            -- FIXME un-xxx this
            -- FIXME this assumes the direction of gravity
            -- FIXME oh!!  my god!!  now you can't walk up one-way platform
            -- slopes!!  because when you hit the corner the clock includes
            -- gravity!!
            if collision.shape._xxx_is_one_way_platform and
                allhits[collision.shape] ~= 1 and (
                    collision.clock:includes(Vector(0, 1))
                    or collision.touchtype <= 0)
            then
                is_passable = true
            end
            if collision.touchtype < 0 then
                -- Objects we're overlapping are always passable
                is_passable = true
            else
                -- FIXME this is better than using worldscene but still assumes
                -- knowledge of the actor api
                local otheractor = self:get_owner(collision.shape)
                local thisactor = self:get_owner(shape)
                if otheractor and not otheractor:blocks(thisactor, collision.movement) then
                    is_passable = true
                end
            end

            -- Restrict our slide angle if the object blocks us
            if is_passable then
                -- FIXME this means the caller will never get a touchtype of
                -- -1?  do i care?  i have a test for it but idk if it matters
                collision.touchtype = 0
            else
                combined_clock:intersect(collision.clock)
            end

            -- If we're hitting the object and it's not passable, stop here
            if allowed_amount == nil and not is_passable and collision.touchtype > 0 then
                allowed_amount = collision.amount
                --print("< found first collision:", collision.movement, "amount:", collision.amount)
            end

            -- Log the first type of contact with each shape
            if allhits[collision.shape] == nil then
                allhits[collision.shape] = collision.touchtype
            end
        end

        -- Automatically break if we don't move for three iterations -- not
        -- moving once is okay because we might slide, but three indicates a
        -- bad loop somewhere
        -- TODO would be nice to avoid this entirely!  it happens, e.g., at the
        -- bottom of the slopetest ramp: position       (606.5,638.5)   velocity        (61.736288265774419415,121.03382860727833759)   movement        (1.5,2.5)
        -- TODO hang on, is it even possible (or reasonable) to not move after the first iteration?
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
        -- TODO wow this is bad naming
        -- TODO this can be an empty clock, which is really an entire clock
        if lastclock and allowed_amount == 0 then
            -- If we don't actually move, then...  this happens...
            -- TODO should this even happen?
            --print("intersecting last clock with combined clock", lastclock, combined_clock)
            lastclock:intersect(combined_clock)
        else
            --print("setting last clock", lastclock, combined_clock)
            lastclock = combined_clock
        end

        -- FIXME this seems like a poor way to get at this logic from outside
        if xxx_no_slide then
            if allowed_amount ~= nil then
                return allowed_amount * attempted, allhits, lastclock
            else
                return attempted, allhits, lastclock
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
        -- FIXME this logic is wrong, and it's because of the clock, naturally!
        -- if we collide with two surfaces simultaneously, there IS no slide!
        -- using lastclock helps, and fixes the case where we wiggle in a
        -- corner without ever hitting both edges simultaneously, but can be
        -- wrong if the movement is much greater than our size (so we slide
        -- along an edge, /beyond/ the object, and then try to slide back
        -- towards it)
        -- actually...  this is exactly the same problem as with one-way platforms.
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

    -- Whatever's left over is unopposed
    --print("TOTAL MOVEMENT:", successful, "OUT OF", dx, dy)

    -- FIXME i would very much like to round movement to the nearest pixel, but
    -- doing so requires finding a rounding direction that's not already
    -- blocked, and at the moment i seem to have much better luck doing no
    -- rounding whatsoever

    return successful, allhits, lastclock
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

    debug_hits = _hits

    return nearestpt, nearest - startdot
end

return {
    Collider = Collider,
}
