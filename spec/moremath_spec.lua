local Vector = require 'vendor.hump.vector'

local util = require 'klinklang.util'
local ClockRange = util.ClockRange

local left = Vector(-1, 0)
local right = Vector(1, 0)
local up = Vector(0, -1)
local down = Vector(0, 1)
local up_left = up + left
local up_right = up + right
local down_left = down + left
local down_right = down + right

describe("ClockRange", function()
    it("should correctly identify containment", function()
        assert.is.truthy(ClockRange.contains(up_left, down, up_left))
        assert.is.truthy(ClockRange.contains(up_left, down, up))
        assert.is.truthy(ClockRange.contains(up_left, down, up_right))
        assert.is.truthy(ClockRange.contains(up_left, down, right))
        assert.is.truthy(ClockRange.contains(up_left, down, down_right))
        assert.is.truthy(ClockRange.contains(up_left, down, down))
        assert.is.falsy(ClockRange.contains(up_left, down, down_left))
        assert.is.falsy(ClockRange.contains(up_left, down, left))
    end)

    it("should consider equality to be containment", function()
        assert.is.truthy(ClockRange.contains(down, down, down))
        assert.is.truthy(ClockRange.contains(down * 3, down * 5, down))

        -- TODO not sure if i want {x, x} to mean everything or just x
        assert.is.falsy(ClockRange.contains(down, down, left))
        assert.is.falsy(ClockRange.contains(down * 3, down * 5, left))

        --assert.is.falsy(ClockRange.contains(down, down, up))
        --assert.is.falsy(ClockRange.contains(down * 3, down * 5, up))
    end)

    it("should correctly handle crossing zero", function()
        local clock = ClockRange(up, down)
        assert.are.same(
            { [up] = true, [down] = true },
            clock:extremes())
    end)

    it("should be able to invert", function()
        local clock1 = ClockRange(up, down)
        local clock2 = ClockRange(down, up)
        assert.are.same(clock2, clock1:inverted())
        assert.are.same(clock1, clock2:inverted())
    end)

    it("should correctly handle unions", function()
        local clock = ClockRange(up, down_right)
        assert.are.same(
            {{right, down_right}, {up, right}},
            clock.ranges)

        clock:union(down, left)
        assert.are.same(
            {{right, down_right}, {down, left}, {up, right}},
            clock.ranges)
    end)

    it("should correctly handle unions 2", function()
        local clock = ClockRange(left, down_right)

        clock:union(up, down)
        assert.are.same(
            ClockRange(left, down).ranges,
            clock.ranges)
    end)

    it("should correctly handle unions 3", function()
        local clock = ClockRange(left, right)

        clock:union(down_left, up_right)
        assert.are.same(
            ClockRange(down_left, right).ranges,
            clock.ranges)
    end)

    it("should correctly handle unions 4", function()
        local clock = ClockRange(up_left, down_right)
        clock:union(left * 32, right)

        assert.are.same(
            ClockRange(left * 32, down_right).ranges,
            clock.ranges)
    end)

    it("should correctly handle intersections", function()
        local clock = ClockRange(down_right, left)

        clock:intersect(down, up)
        assert.are.same(
            {{down, left}},
            clock.ranges)
    end)

    it("should correctly handle intersections spanning zero", function()
        local clock = ClockRange(down_right, up_right)
        assert.are.same(
            {{down_right, up_right}},
            clock.ranges)

        clock:intersect(up_left, down_left)
        assert.are.same(
            {{down_right, down_left}, {up_left, up_right}},
            clock.ranges)
    end)

    it("should correctly handle intersections with non-unit zero", function()
        -- TODO this case
        --initial clock   <ClockRange: (-100,200) to (100,-200)>
        --intersecting with       <ClockRange: (1,0) to (-100,0), (-0,-100) to (1,0)>

        local clock = ClockRange(right * 100, up * 100)
        local clock2 = ClockRange(down * 100, up * 100)
        clock:intersect(clock2)
        assert.are.same(
            clock2.ranges,
            clock.ranges)
    end)
end)
