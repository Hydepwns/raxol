# `Raxol.Terminal.ANSI.DeviceStatus`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/device_status.ex#L1)

Handles terminal state queries and device status reports.
This includes cursor position reports, device status reports,
and terminal identification queries.

# `device_status`

```elixir
@type device_status() :: %{
  cursor_position: {integer(), integer()},
  device_type: String.t(),
  version: String.t(),
  terminal_id: String.t(),
  features: MapSet.t()
}
```

# `cursor_position_report`

```elixir
@spec cursor_position_report(device_status()) :: String.t()
```

Generates a cursor position report.

# `device_status_report`

```elixir
@spec device_status_report(device_status(), :ok | :malfunction) :: String.t()
```

Generates a device status report.

# `fourth_device_attributes`

```elixir
@spec fourth_device_attributes(device_status()) :: String.t()
```

Generates a fourth device attributes report.

# `new`

```elixir
@spec new() :: device_status()
```

Creates a new device status map with default values.

# `primary_device_attributes`

```elixir
@spec primary_device_attributes(device_status()) :: String.t()
```

Generates a primary device attributes report.

# `secondary_device_attributes`

```elixir
@spec secondary_device_attributes(device_status()) :: String.t()
```

Generates a secondary device attributes report.

# `tertiary_device_attributes`

```elixir
@spec tertiary_device_attributes(device_status()) :: String.t()
```

Generates a tertiary device attributes report.

# `update_cursor_position`

```elixir
@spec update_cursor_position(
  device_status(),
  {integer(), integer()}
) :: device_status()
```

Updates the cursor position in the device status.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
