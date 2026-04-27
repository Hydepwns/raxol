# Changelog

All notable changes to `raxol_speech` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-27

Initial release. Speech surface package for Raxol.

### Added

- `Raxol.Speech.Speaker` -- text-to-speech GenServer that subscribes to
  `Raxol.Core.Accessibility` announcements and speaks them aloud. High-priority
  announcements interrupt current speech.
- `Raxol.Speech.TTS.Backend` -- behaviour for TTS implementations.
- `Raxol.Speech.TTS.OsSay` -- macOS `say` / Linux `espeak` backend with text
  sanitization (control char stripping, 10KB max input).
- `Raxol.Speech.TTS.Noop` -- no-op backend for tests and headless environments.
- `Raxol.Speech.Recognizer` -- speech-to-text via Bumblebee/Whisper. Async
  Task-based transcription. Optional dependency on `bumblebee`, `nx`, `exla`.
- `Raxol.Speech.Listener` -- microphone capture via `sox` Port. Bounded by
  `max_duration` and `max_bytes`. Validates `record_command` against an
  allowlist.
- `Raxol.Speech.InputAdapter` -- translates recognized text into Raxol events.
  Ships with 21 default voice commands (e.g. "quit", "up", "scroll down").
- `Raxol.Speech.Supervisor` -- `:rest_for_one` supervisor wiring Speaker,
  Recognizer, and Listener so Listener depends on Recognizer being healthy.

### Notes

- 28 tests, 0 failures.
- STT requires the optional `bumblebee`, `nx`, and `exla` dependencies to be
  added by the consumer. TTS works without any optional deps.
