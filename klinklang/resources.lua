--[[
Tiny class for sticking loaded resources onto.

Can lazy load resources automatically by extension, if you like.  By default,
the manager is locked and will refuse to lazy-load -- this is to prevent
accidentally loading resources outside of the load phase.
]]

local Object = require 'klinklang.object'

local function get_file_ext(path)
    local _start, _end, ext = path:find('[^%./]+%.([^/]+)$')
    return ext
end

local ResourceManager = Object:extend{}

function ResourceManager:init()
    self.loaders = {}
    self.resources = {}
    self.locked = true
end

function ResourceManager:register_default_loaders()
    self:register_loader('png', love.graphics.newImage)
    self:register_loader('wav', function(filename) return love.audio.newSource(filename, "static") end)
    self:register_loader('ogg', function(filename) return love.audio.newSource(filename, "static") end)
end

function ResourceManager:register_loader(ext, loader)
    if self.loaders[ext] then
        error(("Refusing to register duplicate loader for %s"):format(ext))
    end
    self.loaders[ext] = loader
end

function ResourceManager:add(path, resource)
    assert(
        not self.resources[path],
        ("Resource at %s has already been loaded"):format(path))
    self.resources[path] = resource
end

function ResourceManager:get(path)
    return self.resources[path]
end

function ResourceManager:load(path)
    local res = self.resources[path]
    if res then
        return res
    end

    if self.locked then
        error(("Can't load %s while ResourceManager is locked"):format(path))
    end

    local ext = get_file_ext(path)
    local loader = self.loaders[ext]
    if not loader then
        error(("Don't know how to load %s"):format(path))
    end

    res = loader(path)
    -- TODO error if res is nil?
    self.resources[path] = res
    return res
end

return ResourceManager
