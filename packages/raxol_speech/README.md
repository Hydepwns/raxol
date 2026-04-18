# Raxol Speech

Speech surface for Raxol. TTS reads accessibility announcements aloud, STT captures voice input via Bumblebee/Whisper and injects as events.

## Install

```elixir
{:raxol_speech, "~> 0.1"}
```

For speech-to-text, add the optional ML dependencies:

```elixir
{:bumblebee, "~> 0.6"},
{:nx, "~> 0.9"},
{:exla, "~> 0.9"}
```

## Usage

```elixir
# In your supervision tree -- TTS only
children = [
  {Raxol.Speech.Supervisor, tts_backend: Raxol.Speech.TTS.OsSay}
]

# With STT enabled (requires Bumblebee)
children = [
  {Raxol.Speech.Supervisor, enable_stt: true}
]
```

### Text-to-Speech

```elixir
Raxol.Speech.Speaker.speak("Hello world")
Raxol.Speech.Speaker.stop_speaking()
```

The Speaker subscribes to `Raxol.Core.Accessibility` announcements automatically. High-priority announcements interrupt current speech.

### Speech-to-Text

```elixir
Raxol.Speech.Listener.start_recording()
{:ok, text} = Raxol.Speech.Listener.stop_recording()
```

Recognized text is translated to Raxol events via `InputAdapter`. Voice commands like "quit", "up", "scroll down" map to key events.

### Custom TTS Backend

Implement the `Raxol.Speech.TTS.Backend` behaviour:

```elixir
@behaviour Raxol.Speech.TTS.Backend

@impl true
def speak(text), do: ...

@impl true
def stop, do: :ok

@impl true
def speaking?, do: false
```

Use `Raxol.Speech.TTS.Noop` for testing.

See [main docs](../../README.md) for the full Raxol framework.
