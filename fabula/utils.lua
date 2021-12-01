local STATE = require "fabula.state" 
local M = {}

M.format_string = function(s)
	local result = s
	for key, val in pairs(STATE) do
		if type(val) ~= "boolean" then
			result = string.gsub(result, "{" .. key .. "}", val)
		end
	end
	return result
end

----------------------------------------------------------------------

M.check_condition = function(action)
	if action.condition and action.condition_any then
		return M.check_condition({condition = action.condition}) 
		and M.check_condition({condition_any = action.condition_any})
	end

	local condition = action.condition or action.condition_any
	if not condition then
		return true
	end

	local result = action.condition ~= nil

	for k, v in pairs(condition) do
		local check = STATE[k]
		local test = true
		local is_ok = true
		if check == nil then
			local base_check = check
			local suffix_idx = string.find(string.reverse(k), "_")
			local suffix = nil
			if suffix_idx then
				suffix = string.sub(k, -suffix_idx, -1)
				k = string.sub(k, 1, #k - suffix_idx)
				base_check = STATE[k]
			end

			if not base_check then
				base_check = 0
			end

			if type(base_check) == "number" then
				local values = {v}
				if type(v) == "string" then
					values = {tonumber(STATE[v]) or tonumber(v) or 0}
				elseif type(v) == "table" then
					values = {}
					for _, val in ipairs(v) do
						table.insert(values, tonumber(STATE[val]) or tonumber(val) or 0)
					end
				end

				if suffix == "_lte" then
					test = false
					for _, value in ipairs(values) do
						if value < base_check then
							is_ok = false
							break
						end
					end
				elseif suffix == "_lt" then
					test = false
					for _, value in ipairs(values) do
						if value <= base_check then
							is_ok = false
							break
						end
					end
				elseif suffix == "_gte" then
					test = false
					for _, value in ipairs(values) do
						if value > base_check then
							is_ok = false
							break
						end
					end
				elseif suffix == "_gt" then
					test = false
					for _, value in ipairs(values) do
						if value >= base_check then
							is_ok = false
							break
						end
					end
				end
			end
		end

		if test and (not v or v == 0) and not check then
			test = false
		end

		if test and type(check) == "string" then
			v = M.format_string(v)
		end

		if test and v ~= check then
			is_ok = false
		end

		if action.condition then
			result = result and is_ok
		else
			result = result or is_ok
		end
	end

	return result
end

----------------------------------------------------------------------
M.process_template = function (template, action, name)
	local function make_clone(obj)
		local copy = {}
		for key, value in pairs(obj) do
			if type(value) == "table" then
				copy[key] = make_clone(value)
			else
				copy[key] = value
				if type(value) == "string" then
					for k, param in pairs(action) do
						k = (k == name) and "value" or k
						copy[key] = string.gsub(copy[key], "{{" .. k .. "}}", tostring(param))
					end
				end
			end
		end
		return copy
	end

	local clone  = make_clone(template)
	
	if action.condition then
		if clone.condition then
			for k, v in pairs(action.condition) do
				clone.condition[k] = v
			end
		else
			clone.condition = action.condition
		end
	end

	if action.condition_any then
		if clone.condition_any then
			for k, v in pairs(action.condition_any) do
				clone.condition_any[k] = v
			end
		else
			clone.condition_any = action.condition_any
		end
	end

	return clone
end


return M