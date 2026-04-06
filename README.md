# Signal

A high-performance, type-safe signal library for Luau.

## Features

- **Variadic Generics**: Full Luau type safety for event arguments.
- **O(1) Disconnect**: Doubly linked list for constant-time connection removal.
- **Thread Pooling**: Reuse coroutines to minimize overhead.
- **Modern APIs**: Supports `Once`, `WaitTimeout`, and `FireDeferred`.
- **Memory Safe**: Explicit reference clearing to prevent leaks.

## Installation

Add to your `wally.toml`:

```toml
[dependencies]
Signal = "nazumahk/signal@1.0.0"
```

## Quick Start

```lua
local Signal = require(path.to.Signal)

local signal = Signal.new<string, number>()

-- Connect
local connection = signal:Connect(function(msg, val)
    print(msg, val)
end)

-- Fire
signal:Fire("Hello", 100)
signal:FireDeferred("World", 200)

-- Disconnect & Destroy
connection:Disconnect()
signal:Destroy()
```

## Docs
- [Technical Details](docs/WhyUseSignal.md)
- [API Reference](docs/API.md)

## License
MIT