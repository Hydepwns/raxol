defmodule Raxol.Speech.Supervisor do
  @moduledoc """
  Top-level supervisor for the speech surface.

  Starts the Speaker (TTS) and optionally the Listener + Recognizer (STT).
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    tts_backend = Keyword.get(opts, :tts_backend, Raxol.Speech.TTS.OsSay)

    children =
      [
        {Raxol.Speech.Speaker, tts_backend: tts_backend}
      ] ++ stt_children(opts)

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp stt_children(opts) do
    if Keyword.get(opts, :enable_stt, false) do
      [
        {Raxol.Speech.Recognizer, Keyword.get(opts, :recognizer_opts, [])},
        {Raxol.Speech.Listener, Keyword.get(opts, :listener_opts, [])}
      ]
    else
      []
    end
  end
end
