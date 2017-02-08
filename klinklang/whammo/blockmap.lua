--[[
A spatial hash.
]]

local Object = require 'klinklang.object'

local Blockmap = Object:extend()

function Blockmap:init(blocksize)
    self.blocksize = blocksize
    self.quantum = blocksize / 16
    self.blocks = {}
    self.bboxes = setmetatable({}, {__mode = 'k'})
    self.min_x = math.huge
    self.max_x = -math.huge
    self.min_y = math.huge
    self.max_y = -math.huge
end

function Blockmap:to_block_units(x, y)
    return math.floor(x / self.blocksize), math.floor(y / self.blocksize)
end

function Blockmap:block(x, y)
    return self:raw_block(self:to_block_units(x, y))
end

function Blockmap:raw_block(a, b)
    local column = self.blocks[a]
    if not column then
        column = {}
        self.blocks[a] = column
    end
    
    local block = column[b]
    if not block then
        block = setmetatable({}, {__mode = 'k'})
        column[b] = block
    end

    return block
end

function Blockmap:add(obj)
    obj:remember_blockmap(self)
    local x0, y0, x1, y1 = obj:bbox()
    local a0, b0 = self:to_block_units(x0, y0)
    local a1, b1 = self:to_block_units(x1, y1)
    for a = a0, a1 do
        for b = b0, b1 do
            local block = self:raw_block(a, b)
            block[obj] = true
        end
    end
    self.bboxes[obj] = {x0, y0, x1, y1}

    self.min_x = math.min(self.min_x, x0)
    self.max_x = math.max(self.max_x, x1)
    self.min_y = math.min(self.min_y, y0)
    self.max_y = math.max(self.max_y, y1)
end

function Blockmap:remove(obj)
    obj:forget_blockmap(self)
    local x0, y0, x1, y1 = unpack(self.bboxes[obj])
    local a0, b0 = self:to_block_units(x0, y0)
    local a1, b1 = self:to_block_units(x1, y1)
    for a = a0, a1 do
        for b = b0, b1 do
            local block = self:raw_block(a, b)
            block[obj] = nil
        end
    end
    self.bboxes[obj] = nil
end

function Blockmap:update(obj)
    self:remove(obj)
    self:add(obj)
end

function Blockmap:neighbors(obj, dx, dy)
    local x0, y0, x1, y1 = obj:extended_bbox(dx, dy)

    -- Pad by a tiny bit so we can detect, e.g., two objects touching exactly
    -- on a cell edge
    local a0, b0 = self:to_block_units(x0 - self.quantum, y0 - self.quantum)
    local a1, b1 = self:to_block_units(x1 + self.quantum, y1 + self.quantum)
    local ret = {}
    for a = a0, a1 do
        for b = b0, b1 do
            -- Get the block manually, to avoid creating one if not necessary
            local column = self.blocks[a]
            local block
            if column then
                block = column[b]
            end
            if block then
                for neighbor in pairs(block) do
                    ret[neighbor] = true
                end
            end
        end
    end

    -- Objects do not neighbor themselves
    ret[obj] = nil

    return ret
end

-- FIXME this should take a ray width too
-- FIXME there is probably a smarter way to do this?
-- FIXME would like a visualization of this because i don't totally trust it
-- FIXME checks many of the same blocks twice, seen_blocks is unused
-- FIXME walks the entire map even if the nearest neighbor might be right next to us, hm
function Blockmap:neighbors_along_ray(x, y, dx, dy)
    local ex = self.blocksize / 32
    local ey = ex
    if dx > 0 then
        ex = -ex
    end
    if dy > 0 then
        ey = -ey
    end
    local seen_blocks = {}
    local ret = {}
    local stepx = dx * self.blocksize
    local stepy = dy * self.blocksize
    -- Walk a series of bboxes
    while true do
        local x0, y0 = x - ex, y - ey
        local x1, y1 = x + stepx + ex, y + stepy + ey
        local a0, b0 = self:to_block_units(x - ex, y - ey)
        local a1, b1 = self:to_block_units(x + stepx + ex, y + stepy + ey)
        for a = a0, a1 do
            for b = b0, b1 do
                -- Get the block manually, to avoid creating one if not necessary
                local column = self.blocks[a]
                local block
                if column then
                    block = column[b]
                end
                if block then
                    for neighbor in pairs(block) do
                        ret[neighbor] = true
                    end
                end
            end
        end
        x = x + stepx
        y = y + stepy
        -- TODO this is technically not right, since we might be firing the ray
        -- from outside the blockmap /towards/ it.  but that seems unlikely.
        if x < self.min_x or x > self.max_x or y < self.min_y or y > self.max_y then
            break
        end
    end
    return ret
end

return Blockmap
