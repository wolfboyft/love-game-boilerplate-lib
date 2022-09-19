local path = (...):gsub("%.[^%.]+$", "")

local json = require(path .. ".lib.json")

local config = require(path .. ".config")

local settings = {}

local uiLayout, template -- Variables set up by configure

local types = {}
local typeInstanceOrigins = {}

function types.boolean(default)
	assert(type(default) == "boolean", "Non-boolean default for boolean setting")
	local instance = function(try)
		if type(try) == "boolean" then
			return try
		else
			return default
		end
	end
	typeInstanceOrigins[instance] = types.boolean
	return instance
end

local function validComponent(x)
	return type(x) == "number" and 0 <= x and x <= 1
end
function types.rgba(dr, dg, db, da)
	for i = 1, select("#", dr, dg, db, da) do
		assert(validComponent(select(i, dr, dg, db, da)), "Invalid component as default for component " .. i .. " in a colour setting")
	end
	
	local instance = function(try)
		if type(try) ~= "table" then return {dr, dg, db, da} end
		local result = {}
		for i = 1, select("#", dr, dg, db, da) do
			local try = try[i]
			local default = select(i, dr, dg, db, da)
			
			result[i] = validComponent(try) and try or default
		end
		return result
	end
	typeInstanceOrigins[instance] = types.rgba
	return instance
end
function types.rgb(dr, dg, db)
	for i = 1, select("#", dr, dg, db) do
		assert(validComponent(select(i, dr, dg, db)), "Invalid component as default for component " .. i .. " in a colour setting")
	end
	
	local instance = function(try)
		if type(try) ~= "table" then return {dr, dg, db} end
		local result = {}
		for i = 1, select("#", dr, dg, db) do
			local try = try[i]
			local default = select(i, dr, dg, db)
			
			result[i] = validComponent(try) and try or default
		end
		return result
	end
	typeInstanceOrigins[instance] = types.rgb
	return instance
end

local function validNatural(x)
	return type(x) == "number" and math.floor(x) == x and x > 0
end
function types.natural(default)
	assert(validNatural(default), "Non-natural default for natural setting")
	local instance = function(try)
		return validNatural(try) and try or default
	end
	typeInstanceOrigins[instance] = types.natural
	return instance
end

function types.number(default)
	assert(type(default) == "number", "Non-number default for number setting")
	local instance = function(try)
		return type(try) == "number" and try or default
	end
	typeInstanceOrigins[instance] = types.number
	return instance
end

function types.commands(kind, default)
	local instance = function(try)
		if type(try) == "table" then
			local result = {}
			for k, v in pairs(try) do
				if config[kind .. "Commands"][k] then
					if pcall(settings.useScancodesForCommands and love.keyboard.isScancodeDown or love.keyboard.isKeyDown, v) or pcall(love.mouse.isDown, v) then
						result[k] = v
					else
						print("\"" .. v .. "\" is not a valid input to bind to a " .. kind .. " command")
					end
				else
					print("\"" .. k .. "\" is not a valid " .. kind .. " command to bind inputs to")
				end
			end
			return result
		else
			return default
		end
	end
	typeInstanceOrigins[instance] = types.commands
	return instance
end

return setmetatable(settings, {
	__call = function(settings, action, ...)
		if action == "save" then
			local success, message = love.filesystem.write("settings.json", json.encode(settings))
			if not success then print(message) end -- TODO: UX(?)
		
		elseif action == "load" then
			local info = love.filesystem.getInfo("settings.json")
			local decoded
			if info then
				if info.type == "file" then
					decoded = json.decode(love.filesystem.read("settings.json"))
				else
					print("There is already a non-file item called settings.json. Rename it or move it to use custom settings")
				end
			else
				print("Couldn't find settings.json, creating")
			end
			local function traverse(currentTemplate, currentDecoded, currentResult)
				for k, v in pairs(currentTemplate) do
					if type(v) == "table" then
						currentResult[k] = currentResult[k] or {}
						traverse(v, currentDecoded and currentDecoded[k] or nil, currentResult[k])
					elseif type(v) == "function" then
						currentResult[k] = v(currentDecoded and currentDecoded[k])
					else
						error(v .. "is not a valid value in the settings template")
					end
				end
			end
			traverse(template, decoded, settings)
		
		elseif action == "apply" then
			if not select(1, ...) then
				require(path).remakeWindow() -- Avoid circular dependency error
			end
		
		elseif action == "meta" then
			return types, typeInstanceOrigins, template, uiLayout
		
		elseif action == "configure" then
			uiLayout, template = ...
		
		else
			error("Settings is to be called with either \"save\", \"load\", \"apply\", \"meta\", or \"configure\"")
		end
	end
})