# Features

Terminal interface features and framework capabilities.

## Framework Features

### [Agent Framework](AGENT_FRAMEWORK.md)

AI agents as TEA apps with OTP supervision, crash isolation, and inter-agent messaging.

### [Sensor Fusion](SENSOR_FUSION.md)

Poll sensors, fuse readings with weighted averaging and thresholds, render HUD widgets.

### [Distributed Swarm](DISTRIBUTED_SWARM.md)

CRDTs, node monitoring, topology election, tactical overlay. Automatic discovery via libcluster.

### [Adaptive UI](ADAPTIVE_UI.md)

Track pilot behavior, recommend layout changes, animate transitions with a feedback loop.

### [Recording & Replay](RECORDING_REPLAY.md)

Capture terminal sessions as asciinema v2 `.cast` files. Replay with interactive controls.

### [REPL](REPL.md)

Sandboxed interactive Elixir REPL with three safety levels and persistent bindings.

### [Time-Travel Debugging](TIME_TRAVEL_DEBUGGING.md)

Snapshot every `update/2` cycle. Step back, step forward, restore historical state.

## Terminal Features

### [Cursor Effects](CURSOR_EFFECTS.md)

Visual trails and glow: configurable colors, presets, smooth interpolation.

## Performance

All operations are well within the 16ms frame budget (60fps). See [benchmarks](../bench/README.md) for methodology and current numbers.
