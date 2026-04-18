defmodule Raxol.Speech.TTS.Backend do
  @moduledoc """
  Behaviour for text-to-speech backends.

  Implementations convert text strings to audible speech output.
  The framework ships with `OsSay` (macOS/Linux) and `Noop` (testing).
  """

  @doc """
  Speak the given text aloud.

  Implementations may return `:ok` immediately (async, like `OsSay`) or
  block until speech completes. Use `speaking?/0` to check if playback
  is still in progress.
  """
  @callback speak(text :: String.t()) :: :ok | {:error, term()}

  @doc "Stop any currently playing speech."
  @callback stop() :: :ok

  @doc "Returns true if speech is currently playing."
  @callback speaking?() :: boolean()
end
