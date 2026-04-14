# `Raxol.Terminal.TelemetryLogger`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/telemetry_logger.ex#L1)

Logs all Raxol.Terminal telemetry events for observability and debugging.

Call `Raxol.Terminal.TelemetryLogger.attach_all/0` in your application start to enable logging.

## Trace Context

When trace context is available in event metadata, the logger includes
trace_id and span_id for request correlation:

    [TELEMETRY] [trace:abc12345 span:def67890] [:raxol, :terminal, :resized]: %{...}

Use `Raxol.Core.Telemetry.TraceContext` to start traces for request correlation.

# `attach_all`

Attaches the logger to all Raxol.Terminal telemetry events.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
