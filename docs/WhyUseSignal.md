# Why Use Signal?

This document outlines the practical benefits of implementing a custom Signal library over native alternatives or simpler event systems.

## 1. Custom Event Logic

While Roblox provides `RBXScriptSignal` for engine events, developers often need custom signals for game-specific logic (e.g., `OnInventoryUpdate`, `OnGameStateChanged`).

Signals allow you to:
-   Fire events at will with any number of arguments.
-   Maintain full control over the execution lifecycle.

## 2. Superior Type Safety

Standard event systems in Luau often return `any`, leading to potential runtime errors and lack of autocomplete. This Signal implementation uses **Variadic Generics**, ensuring your IDE knows exactly what data is being passed.

```lua
local mySignal = Signal.new<boolean, string>()

mySignal:Connect(function(success, message)
    -- success is boolean, message is string
end)
```

## 3. Predictable Performance

Native `BindableEvent` objects incur overhead due to data serialization and engine-level management. This Signal library operates entirely in pure Luau with:
-   **O(1) Disconnect**: Even with thousands of connections, removing one is a constant-time operation.
-   **Coroutine Reuse**: Minimizes thread allocation costs, making it suitable for high-frequency events (e.g., frame-by-frame updates).

## 4. Enhanced Utility

Traditional signal systems often lack modern control features. This library provides built-in methods for complex scenarios:
-   **WaitTimeout**: Prevents infinite yields by providing a timeout limit.
-   **FireDeferred**: Executes at the end of the frame, preventing race conditions.
-   **Destroy**: Ensures all resources are properly released, preventing memory leaks in long-running projects.

## 5. Professional-Grade Reliability

Explicit reference clearing and a strict metatable ensure that the library is both memory-safe and developer-friendly. It is designed to be the foundation of large-scale, high-performance Roblox frameworks.

---

For a deeper dive into the technical details, see the [Architecture Guide](Architecture.md).
