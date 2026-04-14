# `Raxol.Terminal.SessionManager.Helpers`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session_manager/helpers.ex#L1)

Helper functions for SessionManager operations.

Provides utilities for session cleanup, timing, and other session management tasks.

# `cancel_cleanup_timer`

```elixir
@spec cancel_cleanup_timer(reference() | nil) :: :ok | {:error, :not_found}
```

Cancels a cleanup timer.

## Parameters
  - timer_ref: Timer reference to cancel

## Returns
  - `:ok` if timer was canceled
  - `{:error, :not_found}` if timer doesn't exist

# `create_client`

Creates a Client struct from an id, session_id, and config map.

# `format_session_info`

```elixir
@spec format_session_info(map()) :: String.t()
```

Formats session info for display.

## Parameters
  - session: Session data map

## Returns
  Formatted string

# `generate_client_id`

Generates a unique client ID.

# `generate_session_id`

```elixir
@spec generate_session_id() :: String.t()
```

Generates a unique session ID.

## Returns
  String session ID

# `generate_session_id`

Generates a unique session ID based on name and timestamp.

# `init_network_server`

Initializes the network server for session sharing.

# `merge_session_options`

```elixir
@spec merge_session_options(Keyword.t() | map(), map()) :: map()
```

Merges session options with defaults.

## Parameters
  - opts: User-provided options
  - defaults: Default options

## Returns
  Merged options map

# `send_to_terminal`

Sends input to a terminal process if it is alive.

# `session_expired?`

```elixir
@spec session_expired?(integer(), non_neg_integer()) :: boolean()
```

Checks if a session has expired based on last activity.

## Parameters
  - last_activity: Timestamp of last activity
  - timeout: Timeout duration in milliseconds

## Returns
  Boolean indicating if session is expired

# `start_cleanup_timer`

```elixir
@spec start_cleanup_timer(non_neg_integer()) :: reference()
```

Starts a cleanup timer for periodic session maintenance.

## Parameters
  - interval: Time interval in milliseconds for cleanup

## Returns
  Timer reference

# `validate_session_config`

```elixir
@spec validate_session_config(map()) :: {:ok, map()} | {:error, atom()}
```

Validates session configuration.

## Parameters
  - config: Session configuration map

## Returns
  - `{:ok, config}` if valid
  - `{:error, reason}` if invalid

---

*Consult [api-reference.md](api-reference.md) for complete listing*
