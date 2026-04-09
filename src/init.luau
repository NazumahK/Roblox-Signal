--!strict

--[=[
	@class Connection
	An object representing a connection to a Signal. It allows the management of
	a specific handler function, including disconnecting it from the signal.
	
	```lua
	local connection = mySignal:Connect(function(name, score)
		print(name, score)
	end)
	connection:Disconnect()
	```
]=]
export type Connection<T...> = {
	Connected: boolean,
	Disconnect: (self: Connection<T...>) -> (),
	_signal: Signal<T...>?,
	_fn: ((T...) -> ())?,
	_next: Connection<T...>?,
	_prev: Connection<T...>?,
}

--[=[
	@class Signal
	A high-performance Luau implementation of a signal object, designed for event-driven
	communication with variadic generic support.
	
	```lua
	local onScoreUpdate = Signal.new<string, number>()
	onScoreUpdate:Connect(function(player, score)
		print(player, "now has", score, "points")
	end)
	onScoreUpdate:Fire("Alpha", 100)
	```
]=]
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Wait: (self: Signal<T...>) -> T...,
	WaitTimeout: (self: Signal<T...>, timeout: number) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	FireDeferred: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
	IsDestroyed: (self: Signal<T...>) -> boolean,
	GetConnectionCount: (self: Signal<T...>) -> number,
	_handlerListHead: Connection<T...>?,
	_destroyed: boolean,
}

-- Internally used to store an idle runner thread to minimize thread allocation overhead.
local freeRunnerThread: thread? = nil

--[=[
	Acquires the currently idle runner thread or creates one to execute a handler.
	@private
]=]
local function acquireRunnerThreadAndCallEventHandler(fn: (...any) -> (), ...: any)
	local acquiredRunnerThread: thread? = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	-- Only restore the runner thread if freeRunnerThread hasn't been claimed
	-- by a nested Fire() call during fn(...).
	if freeRunnerThread == nil then
		freeRunnerThread = acquiredRunnerThread
	end
end

--[=[
	The entry point for pooled runner threads. Loops infinitely, waiting for tasks via yield.
	@private
]=]
local function runEventHandlerInFreeThread()
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

local Connection = {}
Connection.__index = Connection

--[=[
	Creates a new Connection instance.
	@private
]=]
function Connection.new<T...>(signal: Signal<T...>, fn: (T...) -> ()): Connection<T...>
	return (
		setmetatable({
			Connected = true,
			_signal = signal :: Signal<T...>?,
			_fn = fn :: ((T...) -> ())?,
			_next = nil :: Connection<T...>?,
			_prev = nil :: Connection<T...>?,
		}, Connection) :: any
	) :: Connection<T...>
end

--[=[
	@method Disconnect
	Terminates the connection between the Signal and the handler.
	
	```lua
	local connection = mySignal:Connect(function() end)
	connection:Disconnect()
	```
]=]
function Connection.Disconnect<T...>(self: Connection<T...>)
	if not self.Connected then
		return
	end

	self.Connected = false

	local prev: Connection<T...>? = self._prev
	local next: Connection<T...>? = self._next
	local signal: Signal<T...>? = self._signal

	if signal then
		if prev then
			prev._next = next
		else
			signal._handlerListHead = next
		end
	end

	if next then
		next._prev = prev
	end

	self._prev = nil
	self._next = nil
	self._fn = nil
	self._signal = nil
end

-- Make Connection strict
-- Internal fields that can be nil must be whitelisted, because Lua treats
-- { key = nil } as absent.  Instance lookup falls through __index = Connection
-- → Connection's metatable __index → error, unless we allow known fields.
local CONNECTION_FIELDS = table.freeze({
	Connected = true, _signal = true, _fn = true, _next = true, _prev = true,
})
setmetatable(Connection, {
	__index = function(_, key)
		if CONNECTION_FIELDS[key] then
			return nil
		end
		error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

local Signal = {}
Signal.__index = Signal

--[=[
	@static .new
	Constructs a new Signal object.
	
	```lua
	local mySignal = Signal.new<string, boolean>()
	```
	
	@return Signal<T...>
]=]
function Signal.new<T...>(): Signal<T...>
	return (
		setmetatable({
			_handlerListHead = nil :: Connection<T...>?,
			_destroyed = false,
		}, Signal) :: any
	) :: Signal<T...>
end

--[=[
	@method Connect
	Connects a handler function to the signal. Returns a Connection object.
	
	```lua
	local connection = onPlayerAdded:Connect(function(player)
		print(player.Name, "joined!")
	end)
	```
	
	@param fn (T...) -> () -- The handler function to connect.
	@return Connection<T...>
]=]
function Signal.Connect<T...>(self: Signal<T...>, fn: (T...) -> ()): Connection<T...>
	if self._destroyed then
		error("Cannot connect to a destroyed signal", 2)
	end

	local connection: Connection<T...> = Connection.new(self, fn)
	local head: Connection<T...>? = self._handlerListHead
	if head then
		head._prev = connection
		connection._next = head
	end
	self._handlerListHead = connection
	return connection
end

--[=[
	@method DisconnectAll
	Disconnects all currently active connections from the signal.
	
	```lua
	mySignal:DisconnectAll()
	```
]=]
function Signal.DisconnectAll<T...>(self: Signal<T...>)
	local item: Connection<T...>? = self._handlerListHead
	while item do
		item.Connected = false
		item._prev = nil
		item._fn = nil
		item._signal = nil
		local next: Connection<T...>? = item._next
		item._next = nil
		item = next
	end
	self._handlerListHead = nil
end

--[=[
	@method Fire
	Invokes all connected handlers immediately with the provided arguments.
	
	```lua
	mySignal:Fire("Alpha", 100)
	```
	
	@param ... T... -- The arguments to pass to the handlers.
]=]
function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	if self._destroyed then
		return
	end

	local item: Connection<T...>? = self._handlerListHead

	while item do
		local fn: ((T...) -> ())? = item._fn
		if item.Connected and fn then
			local runner: thread? = freeRunnerThread
			if runner then
				freeRunnerThread = nil
				task.spawn(runner, fn, ...)
			else
				local newRunner: thread = coroutine.create(runEventHandlerInFreeThread)
				coroutine.resume(newRunner)
				task.spawn(newRunner, fn, ...)
			end
		end
		item = item._next
	end
end

--[=[
	@method FireDeferred
	Queues all connected handlers to be executed at the end of the frame.
	
	```lua
	mySignal:FireDeferred("Beta", 200)
	```
	
	@param ... T... -- The arguments to pass to the handlers.
]=]
function Signal.FireDeferred<T...>(self: Signal<T...>, ...: T...)
	if self._destroyed then
		return
	end

	local item: Connection<T...>? = self._handlerListHead
	while item do
		local fn: ((T...) -> ())? = item._fn
		if item.Connected and fn then
			task.defer(fn, ...)
		end
		item = item._next
	end
end

--[=[
	@method Wait
	Yields the current thread until the signal is fired.
	
	```lua
	task.spawn(function()
		local name, score = mySignal:Wait()
		print(name, "fired with", score)
	end)
	```
	
	@yields
	@return T...
]=]
function Signal.Wait<T...>(self: Signal<T...>): T...
	if self._destroyed then
		error("Cannot wait on a destroyed signal", 2)
	end

	local waitingCoroutine = coroutine.running()
	local cn: Connection<T...>
	cn = self:Connect(function(...: T...)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

--[=[
	@method WaitTimeout
	Yields the current thread until the signal is fired or a timeout occurs.
	
	```lua
	task.spawn(function()
		local success, message = mySignal:WaitTimeout(5)
		if success then
			print("Received:", message)
		else
			warn("Wait timed out!")
		end
	end)
	```
	
	@param timeout number -- Maximum time to wait in seconds.
	@yields
	@return T...
]=]
function Signal.WaitTimeout<T...>(self: Signal<T...>, timeout: number): T...
	if self._destroyed then
		error("Cannot wait on a destroyed signal", 2)
	end

	local waitingCoroutine = coroutine.running()
	local timedOut: boolean = false
	local cn: Connection<T...>

	cn = self:Connect(function(...: T...)
		if not timedOut then
			cn:Disconnect()
			task.spawn(waitingCoroutine, ...)
		end
	end)

	task.delay(timeout, function()
		if cn.Connected then
			timedOut = true
			cn:Disconnect()
			task.spawn(waitingCoroutine, nil)
		end
	end)

	return coroutine.yield()
end

--[=[
	@method Once
	Connects a handler to be executed only once.
	
	```lua
	mySignal:Once(function()
		print("This runs only for the first occurrence.")
	end)
	```
	
	@param fn (T...) -> () -- The handler function.
	@return Connection<T...>
]=]
function Signal.Once<T...>(self: Signal<T...>, fn: (T...) -> ()): Connection<T...>
	if self._destroyed then
		error("Cannot connect to a destroyed signal", 2)
	end

	local cn: Connection<T...>
	cn = self:Connect(function(...: T...)
		if cn.Connected then
			cn:Disconnect()
		end
		fn(...)
	end)
	return cn
end

--[=[
	@method GetConnectionCount
	Returns the total number of active connections.
	
	```lua
	print("Active listeners:", mySignal:GetConnectionCount())
	```
	
	@return number
]=]
function Signal.GetConnectionCount<T...>(self: Signal<T...>): number
	local count: number = 0
	local item: Connection<T...>? = self._handlerListHead
	while item do
		if item.Connected then
			count += 1
		end
		item = item._next
	end
	return count
end

--[=[
	@method IsDestroyed
	Checks whether the signal object has been destroyed.
	
	```lua
	if mySignal:IsDestroyed() then return end
	```
	
	@return boolean
]=]
function Signal.IsDestroyed<T...>(self: Signal<T...>): boolean
	return self._destroyed
end

--[=[
	@method Destroy
	Permanently destroys the signal object and disconnects all handlers.
	
	```lua
	mySignal:Destroy()
	```
]=]
function Signal.Destroy<T...>(self: Signal<T...>)
	if self._destroyed then
		return
	end

	self._destroyed = true
	Signal.DisconnectAll(self)
end

-- Make signal strict
local SIGNAL_FIELDS = table.freeze({ _handlerListHead = true, _destroyed = true })
setmetatable(Signal, {
	__index = function(_, key)
		if SIGNAL_FIELDS[key] then
			return nil
		end
		error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(_, key, _)
		error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
})

return Signal
