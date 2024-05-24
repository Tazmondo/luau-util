export type Future<T> = {
	returnValue: T?,
	complete: boolean,
	callbacks: { thread | (T) -> ...unknown },

	Await: (self: Future<T>) -> T,
	After: (self: Future<T>, after: (T) -> ...unknown) -> (),
	Unwrap: (self: Future<T>) -> T,
	UnwrapOr: (self: Future<T>, default: T) -> T,
	UnwrapOrNil: (self: Future<T>) -> T?,
	IsComplete: (self: Future<T>) -> boolean,
	IsPending: (self: Future<T>) -> boolean,
}

export type TablePcall<T> = {
	success: true,
	value: T,
} | {
	success: false,
	value: unknown,
}

-- since this version of future has no type packs, pcall doesn't work directly
-- also the error type is unknown, not string, because errors arent necessarily strings!
local function TablePcall<R, A...>(callback: (A...) -> R, ...: A...): TablePcall<R>
	local success, result = pcall(callback, ...)

	-- this is a valid union, but type checker doesnt like it
	return {
		success = success,
		value = result,
	} :: any
end

local function Await<T>(self: Future<T>): T
	-- if T is nil then we can't constrain by doing if self.returnValue
	if self.complete then
		return self.returnValue :: T
	end

	table.insert(self.callbacks, coroutine.running())
	return coroutine.yield()
end

local function Unwrap<T>(self: Future<T>): T
	assert(self.complete, "Tried to unwrap a pending future!")
	return self.returnValue :: T
end

local function UnwrapOr<T>(self: Future<T>, default: T): T
	if self.complete then
		return self.returnValue :: T
	end

	return default
end

local function UnwrapOrNil<T>(self: Future<T>): T?
	return self.returnValue
end

local function After<T>(self: Future<T>, after: (T) -> ...unknown)
	if self.complete then
		after(self.returnValue :: T)
		return
	end

	table.insert(self.callbacks, after)
end

local function IsComplete<T>(self: Future<T>)
	return self.complete
end

local function IsPending<T>(self: Future<T>)
	return not self.complete
end

local function Future<T, Args...>(fn: (Args...) -> T, ...: Args...): Future<T>
	local self: Future<T> = {
		complete = false,
		callbacks = {},

		Await = Await,
		After = After,
		Unwrap = Unwrap,
		UnwrapOr = UnwrapOr,
		UnwrapOrNil = UnwrapOrNil,
		IsComplete = IsComplete,
		IsPending = IsPending,
	}

	task.spawn(function(self: Future<T>, fn: (Args...) -> T, ...: Args...)
		self.returnValue = fn(...)
		self.complete = true

		for _, thread in self.callbacks do
			task.spawn(thread, self.returnValue)
		end
	end, self, fn, ...)

	return self
end

local function Try<T, Args...>(fn: (Args...) -> T, ...: Args...): Future<TablePcall<T>>
	return Future(TablePcall, fn, ...)
end

local function ToFuture<T, A...>(fn: (A...) -> T): (A...) -> Future<TablePcall<T>>
	return function(...)
		return Try(fn, ...)
	end
end

local function Value<T>(v: T)
	return Future(function(v: T)
		return v
	end, v)
end

local function All<K, T>(futures: { [K]: Future<T> }): Future<{ [K]: T }>
	return Future(function(futures: { [K]: Future<T> })
		local values: { [K]: T } = {}
		for k, future in futures do
			values[k] = future:Await()
		end

		return values
	end, futures)
end

local function Any<T>(futures: { Future<T> }): Future<T>
	return Future(function(futures: { Future<T> })
		local thread = coroutine.running()
		local returned = false

		for _, future in futures do
			if future:IsComplete() then
				returned = true
				return future:Unwrap()
			end

			future:After(function(...)
				if not returned then
					returned = true
					task.spawn(thread, ...)
				end
			end)
		end

		return coroutine.yield()
	end, futures)
end

return {
	new = Future,
	Try = Try,
	ToFuture = ToFuture,
	Value = Value,
	Any = Any,
	All = All,
}
