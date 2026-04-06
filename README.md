# Signal: A High-Performance, Type-Safe Luau Implementation

Signal is a robust, highly optimized event-driven communication library for the Roblox engine and Luau environments. It is designed to provide a high-fidelity alternative to the native `RBXScriptSignal`, with a focus on maximum throughput, minimal memory overhead, and strict type safety through variadic generics.

## Core Philosophical Principles

1.  **High Throughput**: By utilizing advanced coroutine pooled management, Signal minimizes the overhead associated with thread allocation, ensuring event firing remains a sub-microsecond operation.
2.  **Structural Integrity**: Leveraging a doubly linked list architecture for connection management, providing $O(1)$ time complexity for both registration and deregistration operations.
3.  **Type Determinism**: Built with Luau's variadic generic system, Signal ensures compile-time type checking for all event arguments, significantly reducing runtime errors and improving IDE IntelliSense.
4.  **Defensive Memory Management**: Rigorous reference clearing protocols ensure that once a signal is destroyed or a connection is severed, all internal references to handlers and parent signals are immediately eligible for garbage collection.

## Technical Specifications

| Feature | Specification |
| :--- | :--- |
| **Language** | Luau (Strict Mode) |
| **Data Structure** | Doubly Linked List (DLL) |
| **Execution Model** | Immediate & Deferred (task.defer/task.spawn) |
| **Complexity (Disconnect)** | $O(1)$ |
| **Thread Management** | Coroutine Pooling (Reuse) |
| **Type Support** | Variadic Generics ($T...$) |

## Installation

### Wally (Recommended)

Add the following to your `wally.toml` file:

```toml
[dependencies]
Signal = "nazumahk/signal@1.0.0"
```

## Quick Start Guide

The following example demonstrates a standard lifecycle for a Signal instance within a Luau environment.

```lua
local Signal = require(path.to.Signal)

-- Initializing a signal with type-safe arguments (string and number)
local onScoreUpdate = Signal.new<string, number>()

-- Subscribing to events
local connection = onScoreUpdate:Connect(function(playerName: string, newScore: number)
    print(string.format("Player %s updated score to %d", playerName, newScore))
end)

-- Firing the signal immediately
onScoreUpdate:Fire("Alpha", 500)

-- Firing the signal deferred (Modern Roblox Standard)
onScoreUpdate:FireDeferred("Beta", 750)

-- Severing the connection
connection:Disconnect()

-- Explicit object destruction
onScoreUpdate:Destroy()
```

## Documentation

For a comprehensive technical analysis and API specification, please refer to the following documents:

*   [Technical Whitepaper: Why Use Signal?](docs/WhyUseSignal.md)
*   [API Specification and Reference](docs/API.md)

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for the full license text.