# `Raxol.Terminal.Emulator.Telemetry`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/telemetry.ex#L1)

Telemetry instrumentation for the terminal emulator.

Provides comprehensive error tracking and performance monitoring
for terminal emulation operations.

All events include trace_id and span_id for request correlation.
Use `Raxol.Core.Telemetry.Context` to manage trace context.

# `attach_default_handlers`

Attaches default telemetry handlers for logging.

# `events`

Lists all emulator telemetry events.

# `record_checkpoint_created`

Records checkpoint creation with trace context.

# `record_checkpoint_restored`

Records checkpoint restoration with trace context.

# `record_error`

Records an error event with trace context.

# `record_health_check`

Records a health check with trace context.

# `record_recovery_attempt`

Records a recovery attempt with trace context.

# `record_recovery_failure`

Records a failed recovery with trace context.

# `record_recovery_success`

Records a successful recovery with trace context.

# `span`

Executes a function with telemetry instrumentation.

Automatically includes trace_id and span_id for request correlation.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
