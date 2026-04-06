# API Specification: Signal Library Reference

This document provides a formal, comprehensive reference for the Signal library's types and methods. All methods and properties are strictly typed using Luau's variadic generic system.

---

## Type: `Signal<T...>`

The primary class for event-driven communication.

### Methods

#### `Signal.new<T...>(): Signal<T...>`
Constructs a new Signal object.
- **Returns**: `Signal<T...>` - A typed signal instance.

#### `Signal:Connect(fn: (T...) -> ()): Connection<T...>`
Connects a handler function to the signal.
- **Parameters**:
  - `fn`: The handler function to connect. Signature must match the signal's generic types.
- **Returns**: `Connection<T...>` - A connection object for managing the handler.

#### `Signal:Once(fn: (T...) -> ()): Connection<T...>`
Connects a handler to be executed only once. Automatically disconnects after firing.
- **Parameters**:
  - `fn`: The handler function.
- **Returns**: `Connection<T...>`

#### `Signal:Wait(): T...`
Yields the current thread until the signal is fired.
- **Yields**: Yes.
- **Returns**: `T...` - The arguments passed to the signal.

#### `Signal:WaitTimeout(timeout: number): T...`
Yields the current thread until the signal is fired or a timeout occurs.
- **Parameters**:
  - `timeout`: Maximum time to wait in seconds.
- **Yields**: Yes.
- **Returns**: `T...` - The arguments if fired, or `nil` if timed out.

#### `Signal:Fire(...: T...)`
Invokes all connected handlers immediately with the provided arguments.
- **Parameters**:
  - `...`: The arguments to pass to the handlers.

#### `Signal:FireDeferred(...: T...)`
Queues all connected handlers to be executed at the end of the frame.
- **Parameters**:
  - `...`: The arguments to pass to the handlers.

#### `Signal:DisconnectAll()`
Disconnects all currently active connections from the signal.

#### `Signal:Destroy()`
Permanently destroys the signal object and disconnects all handlers. Reference clearing is automatically performed.

#### `Signal:IsDestroyed(): boolean`
Checks whether the signal object has been destroyed.
- **Returns**: `boolean`

#### `Signal:GetConnectionCount(): number`
Returns the total number of active connections to the signal.
- **Returns**: `number`

---

## Type: `Connection<T...>`

An object representing an active subscription to a Signal.

### Properties

#### `Connection.Connected: boolean`
A read-only property indicating whether the connection is currently active.

### Methods

#### `Connection:Disconnect()`
Severes the connection between the Signal and the handler. The handler will no longer be invoked when the signal fires.

---

## Operational Patterns

### Error Handling in Handlers
All handlers are executed in a separate thread (coroutine). Any error thrown in a handler will not affect other handlers or the thread that fired the signal.

### Memory Lifecycle
Signal objects must be explicitly destroyed using `:Destroy()` when they are no longer needed. While individual connections can be disconnected, destroying the signal ensures that all internal list heads and references are properly cleared for garbage collection.

### Immediate vs. Deferred Firing
- Use `Fire()` when the response must be synchronous and immediate.
- Use `FireDeferred()` when the action can wait until the end of the frame, which is generally safer and more performant in complex engine scenarios.
