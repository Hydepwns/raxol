# Raxol Telegram

Telegram surface bridge for Raxol. Renders TEA apps as monospace code blocks in Telegram chats with inline keyboard navigation.

## Install

```elixir
{:raxol_telegram, "~> 0.1"}
```

For runtime Telegram API access, add:

```elixir
{:telegex, "~> 1.8"}
```

## Usage

```elixir
# In your supervision tree
children = [
  {Raxol.Telegram.Supervisor, app_module: MyApp.CounterApp}
]
```

### Bot Integration

Wire `Raxol.Telegram.Bot.handle_update/1` into your Telegex polling loop or webhook handler:

```elixir
def handle_update(update) do
  Raxol.Telegram.Bot.handle_update(update)
end
```

The bot handles `/start` and `/stop` commands. Other messages and inline keyboard taps are translated to Raxol events and routed to per-chat TEA sessions.

### How It Works

1. Each Telegram chat gets an independent TEA lifecycle (session)
2. The screen buffer renders as `<pre>` HTML in Telegram messages
3. Navigation uses inline keyboards (arrows, tab, enter, quit)
4. Button widgets in the view tree become additional keyboard buttons
5. Sessions auto-expire after 10 minutes of inactivity
6. Message editing avoids spam (re-renders edit the existing message)

### Session Limits

The `SessionRouter` enforces a configurable `max_sessions` cap (default: 1000) to prevent resource exhaustion:

```elixir
{Raxol.Telegram.SessionRouter, app_module: MyApp, max_sessions: 500}
```

See [main docs](../../README.md) for the full Raxol framework.
