# `Raxol.Core.Telemetry.TraceContext`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/telemetry/trace_context.ex#L1)

Trace context management for request correlation across telemetry events.

Provides trace_id and span_id generation and propagation for debugging
and observability. Trace context flows through the process dictionary
for automatic inclusion in telemetry events.

## Usage

    # Start a new trace for a request/operation
    TraceContext.start_trace()

    # Or with a custom trace_id (for distributed tracing)
    TraceContext.start_trace(trace_id: "abc123")

    # Start a child span within a trace
    TraceContext.start_span("render_component")

    # Get current context for logging/telemetry
    ctx = TraceContext.current()
    # => %{trace_id: "abc123", span_id: "def456", parent_span_id: nil}

    # End the current span
    TraceContext.end_span()

## Process Dictionary Keys

- `:raxol_trace_id` - Current trace identifier
- `:raxol_span_id` - Current span identifier
- `:raxol_parent_span_id` - Parent span for nested operations
- `:raxol_span_stack` - Stack of span IDs for nesting

## Integration

The TelemetryAdapter automatically includes trace context in all events
when available. No manual instrumentation needed for basic tracing.

# `context`

```elixir
@type context() :: %{
  trace_id: trace_id() | nil,
  span_id: span_id() | nil,
  parent_span_id: span_id() | nil
}
```

# `span_id`

```elixir
@type span_id() :: String.t()
```

# `trace_id`

```elixir
@type trace_id() :: String.t()
```

# `active?`

```elixir
@spec active?() :: boolean()
```

Checks if there is an active trace context.

# `clear`

```elixir
@spec clear() :: :ok
```

Clears the current trace context.

Call this when a request/operation completes to clean up.

# `current`

```elixir
@spec current() :: context()
```

Returns the current trace context, or empty context if none active.

## Examples

    ctx = TraceContext.current()
    %{trace_id: "abc", span_id: "def", parent_span_id: nil}

# `end_span`

```elixir
@spec end_span() :: context()
```

Ends the current span and restores the parent span.

# `format`

```elixir
@spec format() :: String.t()
```

Formats the current context as a string for logging.

## Examples

    TraceContext.format()
    # => "[trace:abc123 span:def456]"

# `from_headers`

```elixir
@spec from_headers(map()) :: context()
```

Creates context from HTTP headers (for distributed tracing).

## Examples

    TraceContext.from_headers(%{"x-trace-id" => "abc123"})

# `start_span`

```elixir
@spec start_span(String.t()) :: context()
```

Starts a child span within the current trace.

Returns the new context with the child span active.
The parent span is preserved on a stack for proper nesting.

## Examples

    TraceContext.start_span("database_query")
    # ... do work ...
    TraceContext.end_span()

# `start_trace`

```elixir
@spec start_trace(keyword()) :: context()
```

Starts a new trace, optionally with a provided trace_id.

## Options

  * `:trace_id` - Use existing trace_id (for distributed tracing)
  * `:span_name` - Name for the root span (default: "root")

## Examples

    TraceContext.start_trace()
    TraceContext.start_trace(trace_id: "external-123")

# `to_headers`

```elixir
@spec to_headers() :: %{optional(String.t()) =&gt; String.t()}
```

Returns context as a map suitable for HTTP headers or metadata.

## Examples

    headers = TraceContext.to_headers()
    # => %{"x-trace-id" => "abc123", "x-span-id" => "def456"}

# `with_span`

```elixir
@spec with_span(String.t(), (-&gt; result)) :: result when result: term()
```

Executes a function within a new span.

Automatically starts the span before execution and ends it after,
even if the function raises an exception.

## Examples

    result = TraceContext.with_span("render", fn ->
      render_component()
    end)

# `with_trace`

```elixir
@spec with_trace((-&gt; result)) :: result when result: term()
```

Executes a function within a new trace.

Creates a new trace context, executes the function, and clears
the context after completion.

## Examples

    result = TraceContext.with_trace(fn ->
      # All telemetry events here will have trace_id
      process_request()
    end)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
