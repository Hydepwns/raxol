# Without Runtime Examples

This directory contains examples that demonstrate how to use Raxol's low-level APIs without using the application runtime. These examples show how to manually create application loops and handle events.

## Examples

### Hello World
A minimal example showing how to create a terminal application without using the runtime.
```
mix run examples/without-runtime/hello_world.exs
```

### Clock
Demonstrates how to create an application loop with a timer to update the UI periodically.
```
mix run examples/without-runtime/clock.exs
```

### Event Viewer
Shows how to capture and display terminal events like keyboard, mouse, and resize events.
```
mix run examples/without-runtime/event_viewer.exs
``` 