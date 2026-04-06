# API Specification

A formal reference for the Signal library's types and methods.

---

## `Signal<T...>`

The primary class for event-driven communication.

### Methods

#### `Signal.new<T...>(): Signal<T...>`
Constructs a new Signal object.
```lua
local signal = Signal.new<string, number>()
```

#### `Signal:Connect(fn: (T...) -> ()): Connection<T...>`
Connects a handler to the signal.
```lua
local connection = signal:Connect(function(name, score)
    print(name, score)
end)
```

#### `Signal:Once(fn: (T...) -> ()): Connection<T...>`
Connects a handler that executes only once and then disconnects.
```lua
signal:Once(function()
    print("This will only run once")
end)
```

#### `Signal:Wait(): T...`
Suspends the current thread until the signal is fired.
```lua
local name, score = signal:Wait()
```

#### `Signal:WaitTimeout(timeout: number): T...`
Yields the current thread until the signal is fired or a timeout occurs.
```lua
local name, score = signal:WaitTimeout(5)
if name then
    print("Received:", name)
else
    print("Timed out after 5 seconds")
end
```

#### `Signal:Fire(...: T...)`
Invokes all connected handlers immediately.
```lua
signal:Fire("Alpha", 100)
```

#### `Signal:FireDeferred(...: T...)`
Queues all connected handlers to be executed at the end of the frame.
```lua
signal:FireDeferred("Beta", 200)
```

#### `Signal:DisconnectAll()`
Disconnects all active connections.
```lua
signal:DisconnectAll()
```

#### `Signal:Destroy()`
Permanently destroys the signal and clears all internal references.
```lua
signal:Destroy()
```

---

## `Connection<T...>`

Represents a subscription to a Signal.

### Properties

#### `Connection.Connected: boolean`
Returns `true` if the connection is currently active.

### Methods

#### `Connection:Disconnect()`
Severes the connection and clears all references for GC.
```lua
local connection = signal:Connect(function() end)
connection:Disconnect()
print(connection.Connected) -- false
```

---

## Summary

- Use `Fire()` for synchronous responses.
- Use `FireDeferred()` for safe end-of-frame execution.
- Call `:Destroy()` on signals that are no longer needed to prevent leaks.
