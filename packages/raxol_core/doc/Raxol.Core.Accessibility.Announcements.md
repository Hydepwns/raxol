# `Raxol.Core.Accessibility.Announcements`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility/announcements.ex#L1)

Handles screen reader announcements and announcement queue management.

# `add_subscription`

```elixir
@spec add_subscription(reference(), pid()) :: :ok
```

# `announce`

```elixir
@spec announce(String.t(), keyword(), atom() | pid() | nil) :: :ok
```

Make an announcement for screen readers.

## Parameters

* `message` - The message to announce
* `opts` - Options for the announcement
* `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

## Options

* `:priority` - Priority level (`:low`, `:medium`, `:high`) (default: `:medium`)
* `:interrupt` - Whether to interrupt current announcements (default: `false`)

## Examples

    iex> Announcements.announce("Button clicked")
    :ok

    iex> Announcements.announce("Error occurred", priority: :high, interrupt: true)
    :ok

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_announcements`

```elixir
@spec clear_announcements() :: :ok
```

Clear all pending announcements.

## Examples

    iex> Announcements.clear_announcements()
    :ok

# `clear_announcements`

```elixir
@spec clear_announcements(atom() | pid()) :: :ok
```

Clear all pending announcements for a specific user.

## Examples

    iex> Announcements.clear_announcements(:user_prefs)
    :ok

# `get_next_announcement`

```elixir
@spec get_next_announcement(atom() | pid()) :: String.t() | nil
```

Get the next announcement to be read by screen readers for a specific user/context.

## Parameters
* `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

## Examples
    iex> Announcements.get_next_announcement(:user1)
    "Button clicked"

# `get_subscriptions`

```elixir
@spec get_subscriptions() :: %{required(reference()) =&gt; pid()}
```

# `remove_subscription`

```elixir
@spec remove_subscription(reference()) :: :ok
```

# `start_link`

```elixir
@spec start_link(keyword()) :: Agent.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
