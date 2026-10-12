# Zignal

A fast, lightweight, fully typed signal module for Roblox (Luau).

Zignal is built around a doubly linked list of connections and a recycled pool of threads, so connecting and disconnecting are constant-time and firing a signal doesn't create a new thread for every handler.

## Features

- **Typed.** Written in `--!strict`, with generic signatures like `Signal<number, string>`.
- **O(1) `Connect` and `Disconnect`.** Connections unlink themselves without searching the list.
- **Cheap `Fire`.** Firing a signal with no connections is a single field read and a loop check.
- **Thread recycling.** Handler threads are pooled and reused, so repeated `Fire` calls don't keep creating coroutines.
- **Yield-safe.** Every handler runs in its own thread, so a handler that yields never blocks the others.
- **Safe to disconnect while firing.** A connection disconnected earlier in the same `Fire` won't run.
- **Frozen.** The module table and the internal metatables are frozen, so they can't be modified by accident.

## Installation

1. Copy the contents of [`Zignal.lua`](Zignal.lua).
2. In Roblox Studio, create a `ModuleScript` (for example in `ReplicatedStorage`) named `Zignal`.
3. Paste the code into it.

## Quick start

```lua
local Zignal = require(path.to.Zignal)

local signal: Zignal.Signal<string, number> = Zignal.new()

local connection = signal:Connect(function(name, amount)
	print(name, amount)
end)

signal:Fire("Coins", 25) --> Coins 25

connection:Disconnect()
```

A signal that takes no arguments doesn't need any type parameters:

```lua
local ready: Zignal.Signal = Zignal.new()
```

## API

### `Zignal`

| Member | Description |
|---|---|
| `Zignal.new<T...>()` | Creates a new `Signal`. |
| `Zignal.Signal<T...>` | Type of a signal that fires with the arguments `T...`. |
| `Zignal.Connection<T...>` | Type of a connection returned by `Connect` and `Once`. |

### `Signal`

| Method | Returns | Description |
|---|---|---|
| `Signal:Connect(func)` | `Connection` | Runs `func` every time the signal fires. |
| `Signal:Once(func)` | `Connection` | Runs `func` the next time the signal fires, then disconnects itself. |
| `Signal:Wait()` | `T...` | Yields the current thread until the signal fires, then returns the fired arguments. |
| `Signal:Fire(...)` | | Runs every connected handler with the given arguments. |
| `Signal:DisconnectAll()` | | Disconnects every connection on the signal. |

### `Connection`

| Member | Description |
|---|---|
| `Connection.Connected` | `true` until the connection is disconnected. |
| `Connection:Disconnect()` | Disconnects the connection. Safe to call more than once. |

Fields that begin with an underscore (`_next`, `_previous`, `_function`) are internal. Don't read or write them.

## Examples

### Waiting for a signal

```lua
task.spawn(function()
	local name, amount = signal:Wait()
	print("Received", name, amount)
end)

signal:Fire("Gems", 3)
```

### Running a handler once

```lua
signal:Once(function(name)
	print("First fire only:", name)
end)
```

### Disconnecting everything

```lua
signal:DisconnectAll()
```

## Behavior notes

- **Handlers run newest-first.** `Connect` adds the new connection to the front of the list, so the most recently connected handler runs first.
- **`Fire` runs each handler immediately.** A handler runs synchronously until it finishes or yields, then `Fire` moves on to the next one. `Fire` itself never yields.
- **Errors are isolated.** An error in one handler is reported to the output and doesn't stop the other handlers.
- **Disconnecting during a `Fire`.** If a handler disconnects another connection (or calls `DisconnectAll`) before that connection's turn, the disconnected connection doesn't run.
- **`DisconnectAll` doesn't resume waiters.** A thread yielded in `Signal:Wait()` when `DisconnectAll` is called stays suspended, because its connection will never fire.
- **Disconnected connections keep their handler alive** for as long as you keep a reference to the `Connection` object. Drop the reference if you want the handler to be garbage collected.

## Upgrading from 1.x

Version 2.0.0 changes what the module exposes:

- The module now returns a frozen table containing only `new`. Use `Zignal.new()`, and call methods on the signal objects you create. The methods are no longer reachable from the module table itself.
- `Signal` objects no longer have a `new` field, and the `Signal` type no longer includes `new`.
- The `Signal` and `Connection` metatables are frozen and can't be modified.
- `Zignal.Signal` and `Zignal.Connection` can now be written without `<>` when there are no arguments.

See the [release notes](../../releases) for the full list of changes.

## Benchmarks

Times are in seconds for the stated number of calls, so lower is better. `1.0000x` is the fastest in each test, and the other rows are multiples of it. **Old Zignal** is v1.1 and **New Zignal** is v2.0.0. Results vary with hardware, so treat them as relative comparisons.

Complexity is the complexity of the method for that implementation, not of the single run.

<details>
<summary>Show all results</summary>

```txt
Signal.new() (10,000,000x)
1. Old Zignal | 0.434771710 | 1.0000x | O(1)
2. GoodSignal | 0.642974124 | 1.4788x | O(1)
3. New Zignal | 0.652172516 | 1.5000x | O(1)

Connect (2,500,000x)
1. New Zignal | 0.455821270 | 1.0000x | O(1)
2. Old Zignal | 0.480505599 | 1.0541x | O(1)
3. GoodSignal | 0.566573460 | 1.2430x | O(1)

Once (1,500,000x)
1. New Zignal | 0.460882452 | 1.0000x | O(1)
2. Old Zignal | 0.479562526 | 1.0405x | O(1)
3. GoodSignal | 0.545359698 | 1.1833x | O(1)

Wait (250,000x)
1. New Zignal | 0.576629904 | 1.0000x | O(1)
2. Old Zignal | 0.579622250 | 1.0052x | O(1)
3. GoodSignal | 0.639837447 | 1.1096x | O(1)

Fire, 0 Connections (10,000,000x)
1. New Zignal | 0.263348139 | 1.0000x | O(n)
2. GoodSignal | 0.287040696 | 1.0900x | O(n)
3. Old Zignal | 0.486179143 | 1.8461x | O(n)

Fire, 1 Non-Yielding Connection (1,000,000x)
1. GoodSignal | 0.500584590 | 1.0000x | O(n)
2. New Zignal | 0.544047956 | 1.0868x | O(n)
3. Old Zignal | 0.588054219 | 1.1747x | O(n)

Fire, 5 Non-Yielding Connections (200,000x)
1. GoodSignal | 0.476624838 | 1.0000x | O(n)
2. New Zignal | 0.517396476 | 1.0855x | O(n)
3. Old Zignal | 0.528240722 | 1.1083x | O(n)

Fire, 10 Non-Yielding Connections (100,000x)
1. GoodSignal | 0.467305454 | 1.0000x | O(n)
2. New Zignal | 0.515656198 | 1.1034x | O(n)
3. Old Zignal | 0.517871504 | 1.1082x | O(n)

Fire, 1 Yielding Connection (500,000x)
1. New Zignal | 0.548019994 | 1.0000x | O(n)
2. Old Zignal | 0.566385166 | 1.0335x | O(n)
3. GoodSignal | 1.222778276 | 2.2312x | O(n)

Fire, 5 Yielding Connections (100,000x)
1. New Zignal | 0.507846796 | 1.0000x | O(n)
2. Old Zignal | 0.510964664 | 1.0061x | O(n)
3. GoodSignal | 1.166012935 | 2.2960x | O(n)

Fire, 10 Yielding Connections (50,000x)
1. New Zignal | 0.480866126 | 1.0000x | O(n)
2. Old Zignal | 0.482138086 | 1.0026x | O(n)
3. GoodSignal | 1.130791884 | 2.3515x | O(n)

Disconnect, 1 Connection (5,000,000x)
1. New Zignal | 0.415059884 | 1.0000x | O(1)
2. GoodSignal | 0.425906544 | 1.0261x | O(n)
3. Old Zignal | 0.561549756 | 1.3529x | O(1)

Disconnect, 5 Connections, Oldest to Newest (1,000,000x)
1. New Zignal | 0.333451843 | 1.0000x | O(1)
2. Old Zignal | 0.471399354 | 1.4137x | O(1)
3. GoodSignal | 0.483628454 | 1.4503x | O(n)

Disconnect, 10 Connections, Oldest to Newest (500,000x)
1. New Zignal | 0.297224040 | 1.0000x | O(1)
2. Old Zignal | 0.439451252 | 1.4785x | O(1)
3. GoodSignal | 0.642294658 | 2.1609x | O(n)

Disconnect, 5 Connections, Newest to Oldest (1,000,000x)
1. New Zignal | 0.346540810 | 1.0000x | O(1)
2. GoodSignal | 0.351238248 | 1.0135x | O(n)
3. Old Zignal | 0.383276598 | 1.1060x | O(1)

Disconnect, 10 Connections, Newest to Oldest (500,000x)
1. New Zignal | 0.310817155 | 1.0000x | O(1)
2. GoodSignal | 0.317975478 | 1.0230x | O(n)
3. Old Zignal | 0.335007946 | 1.0778x | O(1)

DisconnectAll, 1 Connection (5,000,000x)
1. GoodSignal | 0.270898002 | 1.0000x | O(1) [UNSAFE]
2. New Zignal | 0.338955726 | 1.2512x | O(n)
3. Old Zignal | 0.523689594 | 1.9332x | O(n)

DisconnectAll, 5 Connections (2,500,000x)
1. GoodSignal | 0.134713118 | 1.0000x | O(1) [UNSAFE]
2. New Zignal | 0.299921396 | 2.2263x | O(n)
3. Old Zignal | 0.360078211 | 2.6729x | O(n)

DisconnectAll, 10 Connections (2,000,000x)
1. GoodSignal | 0.109263816 | 1.0000x | O(1) [UNSAFE]
2. New Zignal | 0.352691300 | 3.2278x | O(n)
3. Old Zignal | 0.402166194 | 3.6807x | O(n)
```

</details>

## License

See [LICENSE](LICENSE).
