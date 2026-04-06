# Technical Architecture

This document provides a detailed breakdown of the internal implementation and optimizations of the Signal library.

## 1. Disconnection Logic: O(1) Complexity

Unlike standard array or singly-linked list implementations that require $O(N)$ time to find and remove a node, this library utilizes a **Doubly Linked List (DLL)**. 

Each `Connection` stores `_prev` and `_next` references. This allows any connection to perform a "self-removal" from the signal's internal chain in constant time.

```lua
-- Conceptual DLL Disconnection
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

To avoid the overhead of allocating and garbage collecting thousands of thread objects, the library implements a module-level coroutine pool (`freeRunnerThread`).

-   **Reuse**: After a handler completes, the thread yields back to the pool instead of terminating.
-   **Performance**: This drastically reduces the CPU time spent on thread management during high-frequency events.

```lua
-- Conceptual Coroutine Reuse
local function runEventHandler()
    while true do
        handler_fn(coroutine.yield()) -- Resumes with new arguments
    end
end
```

## 3. Type Safety: Variadic Generics

The library is built on Luau's variadic generic system (`Signal<T...>`). This allows for full end-to-end type safety, from the signal definition to the handler execution.

```lua
local mySignal = Signal.new<string, number>()

mySignal:Connect(function(msg, val)
    -- IDE and compiler know msg is string and val is number
end)

mySignal:Fire("Hello", 100) -- Correct
mySignal:Fire(true, 10)     -- Static Type Error
```

## 4. Memory Management: Defensive Nulling

To prevent memory leaks caused by circular references or captured closures, all internal pointers are explicitly nulled out during disconnection or destruction.

```lua
function Connection:Disconnect()
    self.Connected = false
    -- Crucial for Garbage Collection:
    self._fn = nil
    self._signal = nil
    self._prev = nil
    self._next = nil
end
```

## Summary

The architecture focuses on predictable algorithmic complexity ($O(1)$) and efficient resource usage, ensuring stability for professional-grade systems.
