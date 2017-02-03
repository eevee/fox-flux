-- Simple object implementation.  Based on the one I wrote for Isaac's Descent,
-- but takes a little inspiration from rxi's classic.lua too.

local Object = {}
Object.__index = Object


-- Constructor
function Object:__call(...)
    local this = setmetatable({}, self)
    return this, this:init(...)
end


-- Initializer
function Object:init()
end


-- Subclassing
function Object:extend(proto)
    proto = proto or {}

    -- Copy meta values, since Lua doesn't walk the prototype chain to find them
    for k, v in pairs(self) do
        if k:find("__") == 1 then
            proto[k] = v
        end
    end

    proto.__index = proto
    proto.__super = self

    return setmetatable(proto, self)
end


-- Implementing mixins
function Object:implement(...)
    for _, mixin in pairs{...} do
        for k, v in pairs(mixin) do
            if self[k] == nil and type(v) == "function" then
                print("assigning", k)
                self[k] = v
            end
        end
    end
end


-- Typechecking
function Object:isa(class)
    local meta = getmetatable(self)
    while meta do
        if meta == class then
            return true
        end
        meta = getmetatable(meta)
    end
    return false
end


return Object
