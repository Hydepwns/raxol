# `Raxol.Core.Telemetry.Context`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/telemetry/context.ex#L1)

Trace context propagation for telemetry events.

Provides request correlation across components using trace_id and span_id.
Following OpenTelemetry-compatible patterns for distributed tracing.

## Design

Trace context is stored in the process dictionary and automatically
propagated to child processes. This allows correlating all telemetry
events within a single request/operation.

## Usage

    # Start a new trace (e.g., at request entry point)
    Context.start_trace()

    # Start a child span within a trace
    Context.start_span(:render)

    # Get current context for telemetry metadata
    metadata = Context.to_metadata()
    :telemetry.execute([:raxol, :render, :stop], measurements, metadata)

    # End current span
    Context.end_span()

    # Wrap a function with span instrumentation
    Context.with_span(:database_query, fn ->
      # ... work ...
    end)

## Context Structure

    %{
      trace_id: "abc123def456",      # Unique per request/trace
      span_id: "span789",            # Unique per operation within trace
      parent_span_id: "span456",     # Parent span (for nesting)
      baggage: %{}                   # Additional context to propagate
    }

# `span_id`

```elixir
@type span_id() :: String.t()
```

# `t`

```elixir
@type t() :: %{
  trace_id: trace_id(),
  span_id: span_id(),
  parent_span_id: span_id() | nil,
  baggage: map()
}
```

# `trace_id`

```elixir
@type trace_id() :: String.t()
```

# `capture`

```elixir
@spec capture() :: t() | nil
```

Captures current context for propagation to another process.

## Examples

    # In parent process
    captured = Context.capture()

    # In spawned process
    Task.async(fn ->
      Context.restore(captured)
      # ... work with trace context ...
    end)

# `clear`

```elixir
@spec clear() :: :ok
```

Clears the current trace context.

Call this when a request/operation completes.

# `end_span`

```elixir
@spec end_span() :: t() | nil
```

Ends the current span and returns to the parent span.

# `execute`

```elixir
@spec execute([atom()], map(), map()) :: :ok
```

Executes a telemetry event with trace context automatically injected.

## Examples

    Context.execute([:raxol, :render, :stop], %{duration: 1234}, %{component: :button})

# `get`

```elixir
@spec get() :: t() | nil
```

Gets the current trace context.

Returns nil if no trace is active.

# `get_baggage`

```elixir
@spec get_baggage(atom(), any()) :: any()
```

Gets a baggage value.

# `put_baggage`

```elixir
@spec put_baggage(atom(), any()) :: :ok
```

Sets a baggage value that will be propagated with the trace.

Baggage is additional context that travels with the trace.

## Examples

    Context.put_baggage(:user_id, "user123")
    Context.put_baggage(:request_path, "/api/users")

# `restore`

```elixir
@spec restore(map() | nil) :: :ok
```

Restores captured context in a new process.

# `span`

```elixir
@spec span([atom()], map(), (-&gt; result)) :: result when result: any()
```

Wraps a function with telemetry span instrumentation.

Emits start/stop/exception events with trace context.

## Examples

    result = Context.span([:raxol, :render], %{component: :button}, fn ->
      render_component()
    end)

# `span_id`

```elixir
@spec span_id() :: span_id() | nil
```

Gets the current span_id, or nil if no trace is active.

# `start_span`

```elixir
@spec start_span(atom()) :: t()
```

Starts a new span within the current trace.

Spans can be nested - calling start_span while a span is active
creates a child span.

## Examples

    Context.start_span(:render)
    # ... do rendering ...
    Context.end_span()

# `start_trace`

```elixir
@spec start_trace(keyword()) :: t()
```

Starts a new trace with a unique trace_id.

Call this at the entry point of a request or operation.
Returns the trace context.

## Examples

    context = Context.start_trace()
    # => %{trace_id: "abc123...", span_id: "def456...", ...}

    # With custom trace_id (e.g., from incoming request header)
    context = Context.start_trace(trace_id: "incoming-trace-id")

# `to_metadata`

```elixir
@spec to_metadata(map()) :: map()
```

Converts current context to telemetry metadata map.

Use this to add trace context to telemetry events:

## Examples

    metadata = Context.to_metadata()
    :telemetry.execute([:raxol, :render], measurements, metadata)

    # With additional metadata
    metadata = Context.to_metadata(%{component: :button})

# `trace_id`

```elixir
@spec trace_id() :: trace_id() | nil
```

Gets the current trace_id, or nil if no trace is active.

# `with_span`

```elixir
@spec with_span(atom(), (-&gt; result)) :: result when result: any()
```

Executes a function within a new span.

Automatically starts a span, executes the function, and ends the span.
The span timing is captured for telemetry.

## Examples

    result = Context.with_span(:database_query, fn ->
      Repo.all(User)
    end)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
