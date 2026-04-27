# Changelog

All notable changes to `raxol_watch` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-27

Initial release. Watch surface package for Raxol.

### Added

- `Raxol.Watch.Notifier` -- GenServer that subscribes to
  `Raxol.Core.Accessibility` announcements and pushes to all registered
  devices. 1-second debounce for normal-priority alerts; high-priority
  announcements bypass the debounce. Parallel push via `Task.async_stream`
  with per-device failure logging.
- `Raxol.Watch.DeviceRegistry` -- ETS-backed device registry with
  `read_concurrency: true`. Crash-safe init (re-uses existing table on
  restart). Supports per-device `high_priority_only` preference.
- `Raxol.Watch.Formatter` -- builds notification payloads from accessibility
  announcements and model-state projections. 160-character truncation via
  `String.length` (grapheme-aware). Maps Raxol priority to push priority.
- `Raxol.Watch.ActionHandler` -- maps watch tap actions back to Raxol events.
  Tap routes to `:enter`; "previous" maps to shift+tab.
- `Raxol.Watch.Push.Backend` -- behaviour for push backends.
- `Raxol.Watch.Push.APNS` -- Apple Push Notification Service backend (uses
  optional `pigeon` dependency).
- `Raxol.Watch.Push.FCM` -- Firebase Cloud Messaging backend for Wear OS
  (uses optional `pigeon` dependency).
- `Raxol.Watch.Push.Noop` -- no-op backend for tests; logs a warning if
  configured in `:prod`.
- `Raxol.Watch.Supervisor` -- `:rest_for_one` supervisor wiring
  DeviceRegistry and Notifier (Notifier depends on the registry being up).

### Notes

- 34 tests, 0 failures.
- Real push delivery requires the optional `pigeon` dependency to be added
  by the consumer. The default `Raxol.Watch.Push.Noop` backend works
  without any optional deps and is suitable for tests.
