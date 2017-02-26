local Vector = require 'vendor.hump.vector'

local Object = require 'klinklang.object'
local util = require 'klinklang.util'

-- Allowed rounding error when comparing whether two shapes are overlapping.
-- If they overlap by only this amount, they'll be considered touching.
local PRECISION = 1e-8


local Segment = Object:extend()

function Segment:init(x0, y0, x1, y1)
    self.x0 = x0
    self.y0 = y0
    self.x1 = x1
    self.y1 = y1
end

function Segment:__tostring()
    return ("<Segment: %f, %f to %f, %f>"):format(
        self.x0, self.y0, self.x1, self.y1)
end

function Segment:point0()
    return Vector(self.x0, self.y0)
end

function Segment:point1()
    return Vector(self.x1, self.y1)
end

function Segment:tovector()
    return Vector(self.x1 - self.x0, self.y1 - self.y0)
end

-- Returns the "outwards" normal as a Vector, assuming the points are given
-- clockwise
function Segment:normal()
    return Vector(self.y1 - self.y0, -(self.x1 - self.x0))
end

function Segment:move(dx, dy)
    self.x0 = self.x0 + dx
    self.x1 = self.x1 + dx
    self.y0 = self.y0 + dy
    self.y1 = self.y1 + dy
end


local Shape = Object:extend{
    xoff = 0,
    yoff = 0,
}

function Shape:init()
    self.blockmaps = setmetatable({}, {__mode = 'k'})
end

function Shape:remember_blockmap(blockmap)
    self.blockmaps[blockmap] = true
end

function Shape:forget_blockmap(blockmap)
    self.blockmaps[blockmap] = nil
end

function Shape:update_blockmaps()
    for blockmap in pairs(self.blockmaps) do
        blockmap:update(self)
    end
end

-- Extend a bbox along a movement vector (to enclose all space it might cross
-- along the way)
function Shape:extended_bbox(dx, dy)
    local x0, y0, x1, y1 = self:bbox()

    dx = dx or 0
    dy = dy or 0
    if dx < 0 then
        x0 = x0 + dx
    elseif dx > 0 then
        x1 = x1 + dx
    end
    if dy < 0 then
        y0 = y0 + dy
    elseif dy > 0 then
        y1 = y1 + dy
    end

    return x0, y0, x1, y1
end

function Shape:flipx(axis)
    error("flipx not implemented")
end

function Shape:move(dx, dy)
    error("move not implemented")
end

function Shape:move_to(x, y)
    self:move(x - self.xoff, y - self.yoff)
end

function Shape:draw(mode)
    error("draw not implemented")
end

function Shape:normals()
    error("normals not implemented")
end


-- An arbitrary (CONVEX) polygon
local Polygon = Shape:extend()

-- FIXME i think this blindly assumes clockwise order
function Polygon:init(...)
    Shape.init(self)
    self.edges = {}
    local coords = {...}
    self.coords = coords
    self.x0 = coords[1]
    self.y0 = coords[2]
    self.x1 = coords[1]
    self.y1 = coords[2]
    for n = 1, #coords - 2, 2 do
        table.insert(self.edges, Segment(unpack(coords, n, n + 4)))
        if coords[n + 2] < self.x0 then
            self.x0 = coords[n + 2]
        end
        if coords[n + 2] > self.x1 then
            self.x1 = coords[n + 2]
        end
        if coords[n + 3] < self.y0 then
            self.y0 = coords[n + 3]
        end
        if coords[n + 3] > self.y1 then
            self.y1 = coords[n + 3]
        end
    end
    table.insert(self.edges, Segment(coords[#coords - 1], coords[#coords], coords[1], coords[2]))
    self:_generate_normals()
end

function Polygon:clone()
    -- TODO this shouldn't need to recompute all its segments
    return Polygon(unpack(self.coords))
end

function Polygon:flipx(axis)
    local reverse_coords = {}
    for n = #self.coords - 1, 1, -2 do
        reverse_coords[#self.coords - n] = axis * 2 - self.coords[n]
        reverse_coords[#self.coords - n + 1] = self.coords[n + 1]
    end
    return Polygon(unpack(self.coords))
end

function Polygon:_generate_normals()
    self._normals = {}
    for _, edge in ipairs(self.edges) do
        local normal = edge:normal()
        if normal ~= Vector.zero then
            -- What a mouthful
            self._normals[normal] = normal:normalized()
        end
    end
end

function Polygon:bbox()
    return self.x0, self.y0, self.x1, self.y1
end

function Polygon:move(dx, dy)
    self.xoff = self.xoff + dx
    self.yoff = self.yoff + dy
    self.x0 = self.x0 + dx
    self.x1 = self.x1 + dx
    self.y0 = self.y0 + dy
    self.y1 = self.y1 + dy
    for n = 1, #self.coords, 2 do
        self.coords[n] = self.coords[n] + dx
        self.coords[n + 1] = self.coords[n + 1] + dy
    end
    for _, edge in ipairs(self.edges) do
        edge:move(dx, dy)
    end
    self:update_blockmaps()
end

function Polygon:center()
    -- TODO uhh
    return self.x0 + self.width / 2, self.y0 + self.height / 2
end

function Polygon:draw(mode)
    love.graphics.polygon(mode, self.coords)
end

function Polygon:normals()
    return self._normals
end

function Polygon:project_onto_axis(axis)
    -- TODO maybe use vector-light here
    local minpt = Vector(self.coords[1], self.coords[2])
    local maxpt = minpt
    local min = axis * minpt
    local max = min
    for i = 3, #self.coords, 2 do
        local pt = Vector(self.coords[i], self.coords[i + 1])
        local dot = axis * pt
        if dot < min then
            min = dot
            minpt = pt
        elseif dot > max then
            max = dot
            maxpt = pt
        end
    end
    return min, max, minpt, maxpt
end

-- If this shape were to move by a given distance, would it collide with the
-- given other shape?  If no, returns nil.  If yes, even if the two would slide
-- against each other, returns a table with the following keys:
--   movement: Movement vector, trimmed so it won't collide
--   amount: How much of the given movement can be performed before hitting the
--      other shape, from 0 to 1
--   touchdist: Like `amount`, but how much before touching the other shape,
--      which can be different when two shapes slide
--   touchtype: 1 for collision, 0 for slide, -1 for already overlapping
--   clock: Range of angles that would move the shapes apart
function Polygon:slide_towards(other, movement)
    -- We cannot possibly collide if the bboxes don't overlap
    local ax0, ay0, ax1, ay1 = self:extended_bbox(movement:unpack())
    local bx0, by0, bx1, by1 = other:bbox()
    if (ax1 < bx0 or bx1 < ax0) and (ay1 < by0 or by1 < ay0) then
        return
    end

    -- Use the separating axis theorem.
    -- 1. Choose a bunch of axes, generally normals of the shapes.
    -- 2. Project both shapes along each axis.
    -- 3. If the projects overlap along ANY axis, the shapes overlap.
    --    Otherwise, they don't.
    -- This code also does a couple other things.
    -- b. It uses the direction of movement as an extra axis, in order to find
    --    the minimum possible movement between the two shapes.
    -- a. It keeps values around in terms of their original vectors, rather
    --    than lengths or normalized vectors, to avoid precision loss
    --    from taking square roots.

    if other.subshapes then
        return self:_multi_slide_towards(other, movement)
    end

    -- Mapping of normal vectors (i.e. projection axes) to their normalized
    -- versions (needed for comparing the results of the projection)
    -- FIXME is the move normal actually necessary, or was it just covering up
    -- my bad math before?
    local movenormal = movement:perpendicular()
    movenormal._is_move_normal = true
    local axes = {}
    if movenormal ~= Vector.zero then
        axes[movenormal] = movenormal:normalized()
    end
    for norm, norm1 in pairs(self:normals()) do
        axes[norm] = norm1
    end
    for norm, norm1 in pairs(other:normals()) do
        axes[norm] = norm1
    end

    -- Project both shapes onto each axis and look for the minimum distance
    local maxamt = -math.huge
    local maxnumer, maxdenom
    local touchtype = -1
    -- TODO i would love to get rid of ClockRange, and it starts right here; i
    -- think at most we can return a span of two normals, if you hit a corner
    local clock = util.ClockRange()
    local slide_axis
    local normals = {}  -- set of normals we collided with
    --print("us:", self:bbox())
    --print("them:", other:bbox())
    -- FIXME i can ditch the normalized axes entirely; just need to make sure
    -- no callers are relying on getting them in normals
    for fullaxis, axis in pairs(axes) do
        local min1, max1, minpt1, maxpt1 = self:project_onto_axis(fullaxis)
        local min2, max2, minpt2, maxpt2 = other:project_onto_axis(fullaxis)
        local dist, sep
        if min1 < min2 then
            -- 1 appears first, so take the distance from 1 to 2
            dist = min2 - max1
            sep = minpt2 - maxpt1
        else
            -- Other way around
            dist = min1 - max2
            -- Note that sep is always the vector from us to them
            sep = maxpt2 - minpt1
            -- Likewise, flip the axis so it points towards them
            axis = -axis
            fullaxis = -fullaxis
        end
        -- Ignore extremely tiny overlaps, which are likely precision errors
        if math.abs(dist) < PRECISION then
            dist = 0
        end
        --print("    axis:", fullaxis, "dist:", dist, "sep:", sep, "dot:", dot)
        if dist >= 0 then
            -- This dot product is positive if we're moving closer along this
            -- axis, negative if we're moving away
            local dot = movement * fullaxis
            if math.abs(dot) < PRECISION then
                dot = 0
            end

            if dot < 0 or (dot == 0 and dist > 0) then
                -- Even if the shapes are already touching, they're not moving
                -- closer together, so they can't possibly collide.  Stop here.
                return
            elseif dist == 0 and dot == 0 then
                -- Zero dot and zero distance mean the movement is parallel
                -- and the shapes can slide against each other.  But we still
                -- need to check other axes to know if they'll actually touch.
                slide_axis = fullaxis
            else
                -- Figure out how much movement is allowed, as a fraction.
                -- Conceptually, the answer is the movement projected onto the
                -- axis, divided by the separation projected onto the same
                -- axis.  Stuff cancels, and it turns out to be just the ratio
                -- of dot products (which makes sense).  Vectors are neat.
                -- Note that slides are meaningless here; a shape could move
                -- perpendicular to the axis forever without hitting anything.
                local numer = sep * fullaxis
                local amount = numer / dot
                if math.abs(amount) < PRECISION then
                    amount = 0
                end
                -- TODO i think i could avoid this entirely by using a cross
                -- product instead?
                if math.abs(amount - maxamt) < PRECISION then
                    -- Equal, ish
                    if not fullaxis._is_move_normal then
                        -- FIXME these are no longer de-duplicated, hmm
                        normals[-fullaxis] = -axis
                    end
                elseif amount > maxamt then
                    maxamt = amount
                    maxnumer = numer
                    maxdenom = dot
                    if fullaxis._is_move_normal then
                        normals = {}
                    else
                        normals = { [-fullaxis] = -axis }
                    end
                end
            end

            -- Update touchtype
            if dist > 0 then
                touchtype = 1
            elseif touchtype < 0 then
                touchtype = 0
            end

            -- If the distance isn't negative, then it's possible to move
            -- anywhere in the general direction of this axis
            local perp = fullaxis:perpendicular()
            clock:union(perp, -perp)
        end
    end

    if touchtype < 0 then
        -- Shapes are already colliding
        -- FIXME should have /some/ kind of gentle rejection here; should be
        -- easier now that i have touchdist
        --print("ALREADY COLLIDING", touchtype, worldscene.collider:get_owner(other))
        --error("seem to be inside something!!  stopping so you can debug buddy  <3")
        return {
            movement = Vector.zero,
            amount = 0,
            touchdist = 0,
            touchtype = -1,
            clock = util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO),
            normals = {},
        }
    elseif maxamt > 1 and touchtype > 0 then
        -- We're allowed to move further than the requested distance, AND we
        -- won't end up touching.  (Touching is handled as a slide below!)
        return
    end

    if slide_axis then
        -- This is a slide; we will touch (or are already touching) the other
        -- object, but can continue past it.  (If we wouldn't touch, amount
        -- would exceed 1, and we would've returned earlier.)
        -- touchdist is how far we can move before we touch.  If we're already
        -- touching, then the touch axis will be the max distance, the dot
        -- products above will be zero, and amount will be nonsense.  If not,
        -- amount is correct.
        local touchdist = maxamt
        if touchtype == 1 then
            touchdist = 0
        end
        -- Since we're touching, the slide axis is also a valid normal, along
        -- with any collision normals
        normals[-slide_axis] = -slide_axis:normalized()
        return {
            movement = movement,
            amount = 1,
            touchdist = touchdist,
            touchtype = 0,
            clock = clock,
            normals = normals,
        }
    elseif maxamt == -math.huge then
        -- We don't hit anything at all!
        return
    end

    return {
        -- Minimize rounding error by repeating the same division we used to
        -- get amount, but multiplying first
        movement = movement * maxnumer / maxdenom,
        amount = maxamt,
        touchdist = maxamt,
        touchtype = 1,
        clock = clock,
        normals = normals,
    }
end

function Polygon:_multi_slide_towards(other, movement)
    local ret
    for _, subshape in ipairs(other.subshapes) do
        local collision = self:slide_towards(subshape, movement)
        if collision == nil then
            -- Do nothing
        elseif ret == nil then
            -- First result; just accept it
            ret = collision
        else
            -- Need to combine
            if collision.amount < ret.amount then
                ret = collision
            elseif collision.amount == ret.amount then
                ret.clock:intersect(collision.clock)
                ret.touchdist = math.min(ret.touchdist, collision.touchdist)
                if ret.touchtype == 0 then
                    ret.touchtype = collision.touchtype
                end
                -- FIXME would be nice to de-dupe here too
                for full, norm in pairs(collision.normals) do
                    ret.normals[full] = norm
                end
            end
        end
    end

    return ret
end


-- An AABB, i.e., an unrotated rectangle
local _XAXIS = Vector(1, 0)
local _YAXIS = Vector(0, 1)
local Box = Polygon:extend{
    -- Handily, an AABB only has two normals: the x and y axes
    _normals = { [_XAXIS] = _XAXIS, [_YAXIS] = _YAXIS },
}

function Box:init(x, y, width, height)
    Polygon.init(self, x, y, x + width, y, x + width, y + height, x, y + height)
    self.width = width
    self.height = height
end

function Box:clone()
    return Box(self.x0, self.y0, self.width, self.height)
end

function Box:flipx(axis)
    return Box(axis * 2 - self.x0 - self.width, self.y0, self.width, self.height)
end

function Box:_generate_normals()
end

function Box:center()
    return self.x0 + self.width / 2, self.y0 + self.height / 2
end


local MultiShape = Shape:extend()

function MultiShape:init(...)
    MultiShape.__super.init(self)

    self.subshapes = {}
    for _, subshape in ipairs{...} do
        self:add_subshape(subshape)
    end
end

function MultiShape:add_subshape(subshape)
    -- TODO what if subshape has an offset already?
    table.insert(self.subshapes, subshape)
    self:update_blockmaps()
end

function MultiShape:clone()
    return MultiShape(unpack(self.subshapes))
end

function MultiShape:bbox()
    local x0, x1 = math.huge, -math.huge
    local y0, y1 = math.huge, -math.huge
    for _, subshape in ipairs(self.subshapes) do
        local subx0, suby0, subx1, suby1 = subshape:bbox()
        x0 = math.min(x0, subx0)
        y0 = math.min(y0, suby0)
        x1 = math.max(x1, subx1)
        y1 = math.max(y1, suby1)
    end
    return x0, y0, x1, y1
end

function MultiShape:move(dx, dy)
    self.xoff = self.xoff + dx
    self.yoff = self.yoff + dy
    for _, subshape in ipairs(self.subshapes) do
        subshape:move(dx, dy)
    end
end

function MultiShape:draw(...)
    for _, subshape in ipairs(self.subshapes) do
        subshape:draw(...)
    end
end

function MultiShape:normals()
    local normals = {}
    -- TODO maybe want to compute this only once
    for _, subshape in ipairs(self.subshapes) do
        for k, v in pairs(subshape:normals()) do
            normals[k] = v
        end
    end
    return normals
end

function MultiShape:project_onto_axis(...)
    local min, max, minpt, maxpt
    for i, subshape in ipairs(self.subshapes) do
        if i == 1 then
            min, max, minpt, maxpt = subshape:project_onto_axis(...)
        else
            local min2, max2, minpt2, maxpt2 = subshape:project_onto_axis(...)
            if min2 < min then
                min = min2
                minpt = minpt2
            end
            if max2 > max then
                max = max2
                maxpt = maxpt2
            end
        end
    end
    return min, max, minpt, maxpt
end



return {
    Box = Box,
    MultiShape = MultiShape,
    Polygon = Polygon,
    Segment = Segment,
}
