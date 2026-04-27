# Changelog

All notable changes to `raxol_telegram` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-27

Initial release. Telegram surface bridge for Raxol that renders TEA apps as
monospace `<pre>` HTML blocks in Telegram chats with inline keyboard navigation.

### Added

- `Raxol.Telegram.Bot` -- update handler with optional `allowed_chat_ids`
  access control. Handles `/start` and `/stop` commands and routes other
  messages and inline keyboard taps to per-chat sessions.
- `Raxol.Telegram.SessionRouter` -- per-chat session management with a
  configurable `max_sessions` cap (default 1000) and a 5-second per-chat
  cooldown for rate limiting.
- `Raxol.Telegram.Session` -- TEA lifecycle running in the `:telegram`
  environment. Includes message edit deduplication (re-renders edit the
  existing message instead of spamming new ones) and a 10-minute idle
  timeout.
- `Raxol.Telegram.InputAdapter` -- translates Telegram callback queries and
  text messages into Raxol events.
- `Raxol.Telegram.OutputAdapter` -- renders the screen buffer as
  `<pre>`-wrapped HTML and extracts inline keyboard buttons from the view
  tree in document order.
- `Raxol.Telegram.Supervisor` -- top-level `:rest_for_one` supervisor wiring
  the router and session components together.

### Tests

- 34 tests covering bot routing, session lifecycle, rate limiting, message
  edit dedup, and output rendering.
