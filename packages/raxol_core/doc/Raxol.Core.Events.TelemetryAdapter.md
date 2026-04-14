# `Raxol.Core.Events.TelemetryAdapter`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/events/telemetry_adapter.ex#L1)

Adapter to migrate from EventManager to :telemetry.

This module provides a compatibility layer to gradually migrate the event system
from the custom EventManager to the standard :telemetry library.

## Trace Context

All events automatically include trace context (trace_id, span_id) when available.
Use `Raxol.Core.Telemetry.TraceContext` to start traces and spans.

## Example

    alias Raxol.Core.Telemetry.TraceContext

    # Start a trace for a request
    TraceContext.start_trace()

    # All events will now include trace_id
    TelemetryAdapter.dispatch(:my_event, %{value: 42})
    # => Emits event with metadata: %{trace_id: "abc123", span_id: "def456", ...}

# `dispatch`

Dispatches an event using telemetry.

Converts EventManager dispatch calls to telemetry execute calls.
Automatically includes trace context when available.

# `register_handler`

Registers a handler using telemetry.

Converts EventManager handler registration to telemetry attach.

# `unregister_handler`

Unregisters a handler using telemetry.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
