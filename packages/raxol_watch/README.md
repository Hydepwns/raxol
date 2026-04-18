# Raxol Watch

Watch notification bridge for Raxol. Pushes glanceable summaries and accessibility announcements to Apple Watch (APNS) and Wear OS (FCM). Tap actions route back as events to the TEA app.

## Install

```elixir
{:raxol_watch, "~> 0.1"}
```

For production push notifications, add:

```elixir
{:pigeon, "~> 2.0"}
```

## Usage

```elixir
# In your supervision tree
children = [
  {Raxol.Watch.Supervisor, push_backend: Raxol.Watch.Push.APNS}
]
```

### Device Registration

```elixir
Raxol.Watch.DeviceRegistry.register("device_token_abc", :apns)
Raxol.Watch.DeviceRegistry.register("device_token_xyz", :fcm, high_priority_only: true)
Raxol.Watch.DeviceRegistry.unregister("device_token_abc")
```

### Sending Notifications

```elixir
# From an accessibility announcement
notification = Raxol.Watch.Formatter.format_announcement("Build failed", :high)
Raxol.Watch.Notifier.push_to_all(notification)

# From model state projections
notification = Raxol.Watch.Formatter.format_model_summary("Dashboard", [
  {"CPU", "42%"},
  {"Memory", "1.2 GB"},
  {"Requests", "847/s"}
])
Raxol.Watch.Notifier.push_to_all(notification)
```

The Notifier also subscribes to `Raxol.Core.Accessibility` announcements automatically. High-priority alerts push immediately; normal alerts are debounced (1 second) to respect watch battery.

### Tap Actions

Watch notification actions map back to Raxol events via `ActionHandler`:

```elixir
event = Raxol.Watch.ActionHandler.handle_action("details")
# => Event with key :enter
```

### Custom Push Backend

Implement the `Raxol.Watch.Push.Backend` behaviour. Use `Raxol.Watch.Push.Noop` for testing.

See [main docs](../../README.md) for the full Raxol framework.
