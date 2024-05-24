-- A regular rate limit, returning a boolean for whether a request is allowed or not.
local function new<T>(count: number, interval: number)
	assert(count > 0 and interval > 0, "Count and interval must be >0 for rate limits.")
	local limits: { [T]: number? } = {}

	local function rateLimit(key: T): boolean
		local currentCount = (limits[key] or 0)
		if currentCount >= count then
			return false
		end

		limits[key] = currentCount + 1

		task.delay(interval, function()
			local newCount = assert(limits[key]) - 1

			-- Set to nil when 0 to prevent memory leaks.
			limits[key] = if newCount > 0 then newCount else nil
		end)

		return true
	end

	return rateLimit
end

-- Instead of having the rate limit logic account for the possibility of no key
-- 	just create a wrapper that uses a constant key instead.
local function newGlobal(count: number, interval: number)
	local rateLimit = new(count, interval)

	return function()
		return rateLimit(1)
	end
end

return {
	new = new,
	newGlobal = newGlobal,
}
