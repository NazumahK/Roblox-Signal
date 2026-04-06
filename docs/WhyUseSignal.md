# Technical Architecture

This document providing a summary of the design decisions and optimizations for this Signal implementation.

## 1. Disconnection: O(1) Complexity

Standard arrays or single-linked lists require $O(N)$ time to find and remove a connection. This library uses a **Doubly Linked List**. Each `Connection` object stores `_prev` and `_next` references, allowing a connection to remove itself from the signal without any list traversal.

```lua
-- Conceptual DLL disconnection
-- O(1) - immediate removal of node
if prev then
    prev._next = next
else
    signal._handlerListHead = next
end
if next then
    next._prev = prev
end
```

## 2. Resource Management: Coroutine Pooling

Allocating a new thread for every event fire increases memory pressure and GC frequency. A module-level thread cache (`freeRunnerThread`) is maintained. Handlers are executed within a pooled thread that is yielded and reused.

```lua
-- Coroutine reuse pattern
local function handle()
    while true do
        handler_fn(coroutine.yield()) -- reuse thread
    end
end
```

## 3. Type Safety: Variadic Generics

The signal is built using Luau's variadic generics (`Signal<T...>`). This ensures that parameters passed to `Connect`, `Once`, `Fire`, and `FireDeferred` are statically verified.

```lua
local mySignal = Signal.new<string, number>()

mySignal:Connect(function(msg, val)
    -- IDE knows msg is string, val is number
end)

mySignal:Fire("Hello", 100) -- OK
mySignal:Fire(true, 10)     -- Static Type Error!
```

## 4. Memory Safety

All internal references (`_fn`, `_signal`, `_next`, `_prev`) are explicitly set to `nil` when a connection is severed or a signal is destroyed. This prevents circular references and ensures that captured closures are correctly released.

```lua
function Connection:Disconnect()
    self.Connected = false
    -- Crucial for GC:
    self._fn = nil
    self._signal = nil
end
```

## Summary

This Signal implementation focuses on predictable algorithmic performance and robust memory management while providing full Luau type safety.
