defmodule Raxol.Recording.Player do
  @moduledoc """
  Replays recorded terminal sessions from `.cast` files.

  Writes output events to the terminal at their recorded timing,
  with adjustable playback speed.

  ## Usage

      Player.play("demo.cast")
      Player.play("demo.cast", speed: 2.0)
      Player.play(session, speed: 0.5, max_delay: 3.0)
  """

  alias Raxol.Recording.{Asciicast, Session}

  @default_speed 1.0
  @default_max_delay 5.0

  @doc """
  Plays a .cast file or session struct.

  ## Options

    * `:speed` - Playback speed multiplier (default: 1.0). 2.0 = double speed.
    * `:max_delay` - Cap on delay between events in seconds (default: 5.0).
      Prevents long idle gaps from stalling replay.
  """
  @spec play(Path.t() | Session.t(), keyword()) :: :ok
  def play(path_or_session, opts \\ [])

  def play(path, opts) when is_binary(path) do
    session = Asciicast.read!(path)
    play(session, opts)
  end

  def play(%Session{} = session, opts) do
    speed = Keyword.get(opts, :speed, @default_speed)
    max_delay = Keyword.get(opts, :max_delay, @default_max_delay)

    enter_alt_screen(session)
    play_events(session.events, 0, speed, max_delay)
    leave_alt_screen()

    :ok
  end

  # -- Private --

  defp play_events([], _prev_us, _speed, _max_delay), do: :ok

  defp play_events(
         [{elapsed_us, :output, data} | rest],
         prev_us,
         speed,
         max_delay
       ) do
    delay_us = elapsed_us - prev_us
    delay_ms = round(delay_us / 1_000 / speed)
    max_delay_ms = round(max_delay * 1_000)

    if delay_ms > 0 do
      Process.sleep(min(delay_ms, max_delay_ms))
    end

    IO.write(data)
    play_events(rest, elapsed_us, speed, max_delay)
  end

  defp play_events([_ | rest], prev_us, speed, max_delay) do
    play_events(rest, prev_us, speed, max_delay)
  end

  defp enter_alt_screen(%Session{width: w, height: h}) do
    IO.write("\e[?1049h")
    IO.write("\e[2J\e[H")
    IO.write("\e[8;#{h};#{w}t")
  end

  defp leave_alt_screen do
    IO.write("\e[?1049l")
  end
end
