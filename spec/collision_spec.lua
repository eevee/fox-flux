local Vector = require 'vendor.hump.vector'

local util = require 'klinklang.util'
local whammo = require 'klinklang.whammo'
local whammo_shapes = require 'klinklang.whammo.shapes'

local function do_simple_slide(collider, shape, movement)
    local successful, hits = collider:slide(shape, movement)
    if successful == movement then
        return successful, hits
    end

    -- Just slide once; should be enough for testing purposes
    -- XXX it seems weird to have tests that rely largely on how well this
    -- utility function works.  i would love some tests for the actor stuff
    -- (though i'd need to ditch worldscene, ideally)
    local combined_clock = util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
    for shape, collision in pairs(hits) do
        if not collision.passable then
            combined_clock:intersect(collision.clock)
        end
    end

    local slide = combined_clock:closest_extreme(movement)
    if slide then
        shape:move(successful:unpack())
        local successful2
        successful2, hits = collider:slide(shape, (movement - successful):projectOn(slide))
        return successful + successful2, hits
    else
        return successful, hits
    end
end

describe("Collision", function()
    it("should handle orthogonal movement", function()
        --[[
            +--------+
            | player |
            +--------+
            | floor  |
            +--------+
            movement is straight down; should do nothing
        ]]
        local collider = whammo.Collider(400)
        local floor = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(floor)

        local player = whammo_shapes.Box(0, 0, 100, 100)
        local successful, hits = collider:slide(player, Vector(0, 50))
        assert.are.equal(Vector(0, 0), successful)
        assert.are.equal(1, hits[floor].touchtype)
    end)
    it("should handle diagonal almost-parallel movement", function()
        -- This one is hard to ASCII-art, but the numbers are smaller!
        -- The player is moving towards a shallow slope at an even shallower
        -- angle, and should hit the slope partway up it.  My math used to be
        -- all kinds of bad and didn't correctly handle this case.
        local collider = whammo.Collider(4)
        local floor = whammo_shapes.Polygon(0, 0, 3, -1, 0, -2)
        collider:add(floor)

        local player = whammo_shapes.Box(4, -3, 2, 2)
        local successful, hits = collider:slide(player, Vector(-3, -0.5))
        assert.are.equal(Vector(-2, -1/3), successful)
        assert.are.equal(1, hits[floor].touchtype)
    end)
    it("should stop at the first obstacle", function()
        --[[
                +--------+
                | player |
                +--------+
            +--------+
            | floor1 |+--------+ 
            +--------+| floor2 | 
                      +--------+
            movement is straight down; should hit floor1 and stop
        ]]
        local collider = whammo.Collider(400)
        local floor1 = whammo_shapes.Box(0, 150, 100, 100)
        collider:add(floor1)
        local floor2 = whammo_shapes.Box(100, 200, 100, 100)
        collider:add(floor2)

        local player = whammo_shapes.Box(50, 0, 100, 100)
        local successful, hits = collider:slide(player, Vector(0, 150))
        assert.are.equal(Vector(0, 50), successful)
        assert.are.equal(1, hits[floor1].touchtype)
        assert.are.equal(nil, hits[floor2])
    end)
    it("should allow sliding past an obstacle", function()
        --[[
            +--------+
            |  wall  |
            +--------+
                     +--------+
                     | player |
                     +--------+
            movement is straight up; shouldn't collide
        ]]
        local collider = whammo.Collider(400)
        local wall = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall)

        local player = whammo_shapes.Box(100, 150, 100, 100)
        local successful, hits = collider:slide(player, Vector(0, -150))
        assert.are.equal(Vector(0, -150), successful)
        assert.are.equal(0, hits[wall].touchtype)
    end)
    it("should handle diagonal movement into lone corners", function()
        --[[
            +--------+
            |  wall  |
            +--------+
                       +--------+
                       | player |
                       +--------+
            movement is up and to the left (more left); should slide left along
            the ceiling
        ]]
        local collider = whammo.Collider(400)
        local wall = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall)

        local player = whammo_shapes.Box(200, 150, 100, 100)
        local successful, hits = do_simple_slide(collider, player, Vector(-200, -100))
        assert.are.equal(-200, successful.x)
        assert.are.equal(0, hits[wall].touchtype)
    end)
    it("should handle diagonal movement into corners with walls", function()
        --[[
            +--------+
            | wall 1 |
            +--------+--------+
            | wall 2 | player |
            +--------+--------+
            movement is up and to the left; should slide along the wall upwards
        ]]
        local collider = whammo.Collider(400)
        local wall1 = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall1)
        local wall2 = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(wall2)

        local player = whammo_shapes.Box(100, 100, 100, 100)
        local successful, hits = do_simple_slide(collider, player, Vector(-50, -50))
        assert.are.equal(Vector(0, -50), successful)
        assert.are.equal(0, hits[wall1].touchtype)
        assert.are.equal(0, hits[wall2].touchtype)
    end)
    it("should handle movement blocked in multiple directions", function()
        --[[
            +--------+--------+
            | wall 1 | wall 2 |
            +--------+--------+
            | wall 3 | player |
            +--------+--------+
            movement is up and to the left; should not move at all
        ]]
        local collider = whammo.Collider(400)
        local wall1 = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall1)
        local wall2 = whammo_shapes.Box(100, 0, 100, 100)
        collider:add(wall2)
        local wall3 = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(wall3)

        local player = whammo_shapes.Box(100, 100, 100, 100)
        local successful, hits = collider:slide(player, Vector(-50, -50))
        assert.are.equal(Vector(0, 0), successful)
        assert.are.equal(1, hits[wall1].touchtype)
        assert.are.equal(1, hits[wall2].touchtype)
        assert.are.equal(1, hits[wall3].touchtype)
    end)
    it("should slide you down when pressed against a corner", function()
        --[[
                     +--------+
            +--------+ player |
            |  wall  +--------+
            +--------+
            movement is down and to the left; should slide down along the wall
            at full speed
        ]]
        local collider = whammo.Collider(400)
        local wall = whammo_shapes.Box(0, 50, 100, 100)
        collider:add(wall)

        local player = whammo_shapes.Box(100, 0, 100, 100)
        local successful, hits = do_simple_slide(collider, player, Vector(-100, 50))
        assert.are.equal(Vector(0, 50), successful)
        assert.are.equal(0, hits[wall].touchtype)
    end)
    it("should slide you down when pressed against a wall", function()
        --[[
            +--------+
            | wall 1 +--------+
            +--------+ player |
            | wall 2 +--------+
            +--------+
            movement is down and to the left; should slide down along the wall
            at full speed
        ]]
        local collider = whammo.Collider(400)
        local wall1 = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall1)
        local wall2 = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(wall2)

        local player = whammo_shapes.Box(100, 50, 100, 100)
        local successful, hits = do_simple_slide(collider, player, Vector(-50, 100))
        assert.are.equal(Vector(0, 100), successful)
        assert.are.equal(0, hits[wall1].touchtype)
        assert.are.equal(0, hits[wall2].touchtype)
    end)
    it("should slide you along slopes", function()
        --[[
            +--------+
            | player |
            +--------+
            | ""--,,_
            | floor  +    (this is actually a triangle)
            +--------+
            movement is straight down; should slide rightwards along the slope
        ]]
        local collider = whammo.Collider(400)
        local floor = whammo_shapes.Polygon(0, 100, 100, 150, 0, 150)
        collider:add(floor)

        local player = whammo_shapes.Box(0, 0, 100, 100)
        local successful, hits = do_simple_slide(collider, player, Vector(0, 100))
        assert.are.equal(Vector(40, 20), successful)
        assert.are.equal(0, hits[floor].touchtype)
    end)
    it("should not put you inside slopes", function()
        --[[
            +--------+
            | player |
            +--------+
            | ""--,,_
            | floor  +    (this is actually a triangle)
            +--------+
            movement is straight down; should slide rightwards along the slope
        ]]
        local collider = whammo.Collider(64)
        -- Unlike above, this does not make a triangle with nice angles; the
        -- results are messy floats.
        -- Also, if it weren't obvious, this was taken from an actual game.
        local floor = whammo_shapes.Polygon(400, 552, 416, 556, 416, 560, 400, 560)
        collider:add(floor)

        local player = whammo_shapes.Box(415 - 8, 553 - 29, 13, 28)
        local successful, hits = collider:slide(player, Vector(0, 2))
        assert.are.equal(1, hits[floor].touchtype)

        -- We don't actually care about the exact results; we just want to be
        -- sure we aren't inside the slope on the next tic
        local successful, hits = collider:slide(player, Vector(0, 10))
        assert.are.equal(1, hits[floor].touchtype)
    end)
    --[==[ TODO i...  am not sure how to make this work yet
    it("should quantize correctly", function()
        --[[
            +-----+--------+
            |wall/| player |
            |   / +--------+
            |  /
            | /
            |/
            +-------+
            | floor |
            +-------+
            movement is exactly parallel to the wall.  however, the floor is
            not pixel-aligned, so the final position won't be either, and we'll
            need to back up to find a valid pixel.  we should NOT end up inside
            the wall.

            FIXME for bonus points, do this in all eight directions
        ]]
        local collider = whammo.Collider(64)
        local wall = whammo_shapes.Polygon(0, 0, 100, 0, 0, 200)
        collider:add(wall)
        -- yes, the floor overlaps the wall, it's fine
        local floor = whammo_shapes.Box(0, 199.5, 200, 200)
        collider:add(floor)

        local player = whammo_shapes.Box(100, 0, 100, 100)
        local successful, hits = collider:slide(player, Vector(-100, 200))
        --assert.are.equal(Vector(-49, 98), successful)
        assert.are.equal(1, hits[wall].touchtype)
        assert.are.equal(1, hits[floor].touchtype)
        local successful, hits = collider:slide(player, Vector(-100, 200))
        local successful, hits = collider:slide(player, Vector(-100, 200))
        local successful, hits = collider:slide(player, Vector(-100, 200))
    end)
    ]==]
    it("should not round you into a wall", function()
        --[[
            +-----+
            |wall/
            |   /   +--------+
            |  /    | player |
            | /     +--------+
            |/
            +
            movement is left and down; should slide along the wall and NOT be
            inside it on the next frame
        ]]
        local collider = whammo.Collider(64)
        -- Unlike above, this does not make a triangle with nice angles; the
        -- results are messy floats.
        -- Also, if it weren't obvious, this was taken from an actual game.
        local x, y = 492, 1478
        local wall = whammo_shapes.Polygon(x + 0, y + 0, x - 18, y + 62, x - 18, y + 0)
        collider:add(wall)
        local floor = whammo_shapes.Box(510 - 62, 1540, 62, 14)
        collider:add(floor)

        local player = whammo_shapes.Box(491.125 - 8, 1537.75 - 29, 13, 28)
        local successful, hits = collider:slide(player, Vector(-1, 2.25))
        assert.are.equal(1, hits[wall].touchtype)

        -- We don't actually care about the exact results; we just want to be
        -- sure we aren't inside the slope on the next tic
        local successful, hits = collider:slide(player, Vector(-0.875, 2.375))
        assert.are.equal(1, hits[wall].touchtype)
    end)
    it("should not register slides against objects out of range", function()
        --[[
            +--------+
            | player |
            +--------+    +--------+--------+
                          | floor1 | floor2 |
                          +--------+--------+
            movement is directly right; should not be blocked at all, should
            slide on floor 1, should NOT slide on floor 2
        ]]
        local collider = whammo.Collider(400)
        local floor1 = whammo_shapes.Box(150, 100, 100, 100)
        collider:add(floor1)
        local floor2 = whammo_shapes.Box(250, 100, 100, 100)
        collider:add(floor2)

        local player = whammo_shapes.Box(0, 0, 100, 100)
        local successful, hits = collider:slide(player, Vector(100, 0))
        assert.are.equal(Vector(100, 0), successful)
        assert.are_equal(0, hits[floor1].touchtype)
        assert.are_equal(nil, hits[floor2])
    end)
    it("should count touches even when not moving", function()
        --[[
                     +--------+
                     | player |
            +--------+--------+--------+
            | floor1 | floor2 | floor3 |
            +--------+--------+--------+
            movement is nowhere; should touch all three floors
            at full speed
        ]]
        local collider = whammo.Collider(400)
        local floor1 = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(floor1)
        local floor2 = whammo_shapes.Box(100, 100, 100, 100)
        collider:add(floor2)
        local floor3 = whammo_shapes.Box(200, 100, 100, 100)
        collider:add(floor3)

        local player = whammo_shapes.Box(100, 0, 100, 100)
        local successful, hits = collider:slide(player, Vector(0, 0))
        assert.are.equal(Vector(0, 0), successful)
        assert.are.equal(0, hits[floor1].touchtype)
        assert.are.equal(0, hits[floor2].touchtype)
        assert.are.equal(0, hits[floor3].touchtype)
    end)
    it("should ignore existing overlaps", function()
        --[[
                    +--------+
            +-------++player |
            | floor ++-------+
            +--------+
            movement is to the left; shouldn't block us at all
        ]]
        local collider = whammo.Collider(400)
        local floor = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(floor)

        local player = whammo_shapes.Box(80, 80, 100, 100)
        local successful, hits = collider:slide(player, Vector(-200, 0))
        assert.are.equal(Vector(-200, 0), successful)
        assert.are.equal(-1, hits[floor].touchtype)
    end)

    it("should not let you fall into the floor", function()
        --[[
            Actual case seen when playing:
            +--------+
            | player |
            +--------+--------+
            | floor1 | floor2 |
            +--------+--------+
            movement is right and down (due to gravity)
        ]]
        local collider = whammo.Collider(4 * 32)
        local floor1 = whammo_shapes.Box(448, 384, 32, 32)
        collider:add(floor1)
        local floor2 = whammo_shapes.Box(32, 256, 32, 32)
        collider:add(floor2)

        local player = whammo_shapes.Box(443, 320, 32, 64)
        local successful, hits = do_simple_slide(collider, player, Vector(4.3068122830999, 0.73455352286288))
        assert.are.equal(Vector(4.3068122830999, 0), successful)
        -- XXX this is 0 because the last movement was a slide, but obviously
        -- you DID collide with it...  within the game that's tested with the
        -- callback though
        assert.are.equal(0, hits[floor1].touchtype)
    end)

    it("should allow near misses", function()
        --[[
            Actual case seen when playing:
                    +--------+
                    | player |
                    +--------+

            +--------+
            | floor  |
            +--------+
            movement is right and down, such that the player will not actually
            touch the floor
        ]]
        local collider = whammo.Collider(4 * 100)
        local floor = whammo_shapes.Box(0, 250, 100, 100)
        collider:add(floor)

        local player = whammo_shapes.Box(0, 0, 100, 100)
        local move = Vector(150, 150)
        local successful, hits = collider:slide(player, move)
        assert.are.equal(move, successful)
        assert.are.equal(nil, hits[floor])
    end)
end)
