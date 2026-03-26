defmodule Raxol.Recording.Player do
  @moduledoc """
  Replays recorded terminal sessions from `.cast` files.

  Writes output events to the terminal at their recorded timing,
  with interactive controls for pause, speed, seek, and quit.

  ## Usage

      Player.play("demo.cast")
      Player.play("demo.cast", speed: 2.0)
      Player.play(session, speed: 0.5, max_delay: 3.0)

  ## Controls during playback

    * `space` - Pause / resume
    * `+` / `=` - Increase speed (1x -> 2x -> 4x -> 8x)
    * `-` - Decrease speed (8x -> 4x -> 2x -> 1x -> 0.5x -> 0.25x)
    * `>` / `.` - Skip forward 5 seconds
    * `<` / `,` - Skip backward 5 seconds
    * `0`..`9` - Jump to 0%-90% of recording
    * `q` / `ESC` - Quit
  """

  alias Raxol.Recording.{Asciicast, Session}

  @default_speed 1.0
  @default_max_delay 5.0
  @speed_steps [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
  @seek_step_us 5_000_000

  @doc """
  Plays a .cast file or session struct.

  ## Options

    * `:speed` - Playback speed multiplier (default: 1.0). 2.0 = double speed.
    * `:max_delay` - Cap on delay between events in seconds (default: 5.0).
    * `:interactive` - Enable keyboard controls (default: true).
  """
  @spec play(Path.t() | Session.t(), keyword()) :: :ok
  def play(path_or_session, opts \\ [])

  def play(path, opts) when is_binary(path) do
    session = Asciicast.read!(path)
    play(session, opts)
  end

  def play(%Session{} = session, opts) do
    interactive = Keyword.get(opts, :interactive, true)

    if interactive do
      play_interactive(session, opts)
    else
      play_simple(session, opts)
    end
  end

  # -- Simple (non-interactive) playback --

  defp play_simple(%Session{} = session, opts) do
    speed = Keyword.get(opts, :speed, @default_speed)
    max_delay = Keyword.get(opts, :max_delay, @default_max_delay)

    enter_alt_screen(session)
    play_events_simple(session.events, 0, speed, max_delay)
    leave_alt_screen()

    :ok
  end

  defp play_events_simple([], _prev_us, _speed, _max_delay), do: :ok

  defp play_events_simple([{elapsed_us, :output, data} | rest], prev_us, speed, max_delay) do
    delay_us = elapsed_us - prev_us
    delay_ms = round(delay_us / 1_000 / speed)
    max_delay_ms = round(max_delay * 1_000)

    if delay_ms > 0 do
      Process.sleep(min(delay_ms, max_delay_ms))
    end

    IO.write(data)
    play_events_simple(rest, elapsed_us, speed, max_delay)
  end

  defp play_events_simple([_ | rest], prev_us, speed, max_delay) do
    play_events_simple(rest, prev_us, speed, max_delay)
  end

  # -- Interactive playback --

  defp play_interactive(%Session{} = session, opts) do
    speed = Keyword.get(opts, :speed, @default_speed)
    max_delay = Keyword.get(opts, :max_delay, @default_max_delay)
    events = session.events
    total_us = total_duration_us(events)

    state = %{
      events: events,
      index: 0,
      speed: speed,
      max_delay: max_delay,
      paused: false,
      total_us: total_us,
      session: session
    }

    enter_alt_screen(session)
    old_settings = set_raw_mode()

    try do
      show_status_bar(state)
      loop(state)
    after
      restore_terminal(old_settings)
      leave_alt_screen()
    end

    :ok
  end

  defp loop(%{index: idx, events: events}) when idx >= length(events), do: :ok

  defp loop(%{paused: true} = state) do
    case read_key(100) do
      :none -> loop(state)
      key -> handle_key(key, state)
    end
  end

  defp loop(state) do
    {elapsed_us, :output, data} = current_event(state)
    prev_us = prev_elapsed_us(state)

    delay_us = elapsed_us - prev_us
    delay_ms = round(delay_us / 1_000 / state.speed)
    max_delay_ms = round(state.max_delay * 1_000)
    actual_delay = min(max(delay_ms, 0), max_delay_ms)

    case wait_with_input(actual_delay) do
      :timeout ->
        IO.write(data)
        state = %{state | index: state.index + 1}
        show_status_bar(state)
        loop(state)

      key ->
        handle_key(key, state)
    end
  end

  defp handle_key(key, state) do
    case key do
      :quit ->
        :ok

      :pause ->
        state = %{state | paused: !state.paused}
        show_status_bar(state)
        loop(state)

      :speed_up ->
        state = %{state | speed: next_speed(state.speed)}
        show_status_bar(state)
        loop(state)

      :speed_down ->
        state = %{state | speed: prev_speed(state.speed)}
        show_status_bar(state)
        loop(state)

      :seek_forward ->
        state = seek(state, @seek_step_us)
        show_status_bar(state)
        loop(state)

      :seek_backward ->
        state = seek(state, -@seek_step_us)
        show_status_bar(state)
        loop(state)

      {:jump, pct} ->
        state = jump_to_percent(state, pct)
        show_status_bar(state)
        loop(state)

      :unknown ->
        loop(state)
    end
  end

  # -- Seeking --

  defp seek(state, delta_us) do
    current_us = current_elapsed_us(state)
    target_us = current_us + delta_us
    jump_to_us(state, target_us)
  end

  defp jump_to_percent(state, pct) do
    target_us = round(state.total_us * pct / 100)
    jump_to_us(state, target_us)
  end

  defp jump_to_us(state, target_us) do
    target_us = max(0, min(target_us, state.total_us))

    idx =
      Enum.find_index(state.events, fn {elapsed_us, _, _} ->
        elapsed_us >= target_us
      end) || length(state.events)

    # Replay all output up to idx to reconstruct screen state
    IO.write("\e[2J\e[H")

    state.events
    |> Enum.take(idx)
    |> Enum.each(fn
      {_, :output, data} -> IO.write(data)
      _ -> :ok
    end)

    %{state | index: idx}
  end

  # -- Key reading --

  defp wait_with_input(0), do: :timeout

  defp wait_with_input(delay_ms) do
    # Poll in 50ms chunks so keys are responsive
    chunk = min(delay_ms, 50)

    case read_key(chunk) do
      :none when delay_ms <= chunk -> :timeout
      :none -> wait_with_input(delay_ms - chunk)
      key -> key
    end
  end

  defp read_key(timeout_ms) do
    case IO.getn("", 1, timeout_ms) do
      :eof -> :quit
      {:error, _} -> :none
      "" -> :none
      <<char>> -> parse_key(char)
      # IO.getn may return a string on some platforms
      str when is_binary(str) and byte_size(str) > 0 -> parse_key(:binary.first(str))
      _ -> :none
    end
  end

  defp parse_key(char) do
    case char do
      ?q -> :quit
      ?\e -> :quit
      ?\s -> :pause
      ?+ -> :speed_up
      ?= -> :speed_up
      ?- -> :speed_down
      ?> -> :seek_forward
      ?. -> :seek_forward
      ?< -> :seek_backward
      ?, -> :seek_backward
      n when n in ?0..?9 -> {:jump, (n - ?0) * 10}
      _ -> :unknown
    end
  end

  # -- Speed steps --

  defp next_speed(current) do
    @speed_steps
    |> Enum.find(current, fn s -> s > current end)
  end

  defp prev_speed(current) do
    @speed_steps
    |> Enum.reverse()
    |> Enum.find(current, fn s -> s < current end)
  end

  # -- Status bar --

  defp show_status_bar(state) do
    height = state.session.height
    current_us = current_elapsed_us(state)
    current_s = Float.round(current_us / 1_000_000, 1)
    total_s = Float.round(state.total_us / 1_000_000, 1)
    pct = if state.total_us > 0, do: round(current_us / state.total_us * 100), else: 0

    speed_label = format_speed(state.speed)
    pause_label = if state.paused, do: " [PAUSED]", else: ""

    bar =
      " #{current_s}s/#{total_s}s (#{pct}%) | #{speed_label}#{pause_label} | " <>
        "space:pause +/-:speed </>:seek q:quit"

    # Truncate to width
    bar = String.slice(bar, 0, state.session.width)

    # Save cursor, move to status line, write inverted, restore cursor
    IO.write("\e7\e[#{height};1H\e[7m#{String.pad_trailing(bar, state.session.width)}\e[0m\e8")
  end

  defp format_speed(speed) when speed == round(speed), do: "#{round(speed)}x"
  defp format_speed(speed), do: "#{speed}x"

  # -- Event helpers --

  defp current_event(%{events: events, index: idx}), do: Enum.at(events, idx)

  defp current_elapsed_us(%{index: idx, events: events}) when idx >= length(events) do
    case List.last(events) do
      {us, _, _} -> us
      nil -> 0
    end
  end

  defp current_elapsed_us(%{events: events, index: idx}) do
    {us, _, _} = Enum.at(events, idx)
    us
  end

  defp prev_elapsed_us(%{index: 0}), do: 0

  defp prev_elapsed_us(%{events: events, index: idx}) do
    {us, _, _} = Enum.at(events, idx - 1)
    us
  end

  defp total_duration_us([]), do: 0

  defp total_duration_us(events) do
    {us, _, _} = List.last(events)
    us
  end

  # -- Terminal mode --

  defp set_raw_mode do
    old = System.cmd("stty", ["-g"], stderr_to_stdout: true) |> elem(0) |> String.trim()
    System.cmd("stty", ["raw", "-echo"], stderr_to_stdout: true)
    # Hide cursor
    IO.write("\e[?25l")
    old
  end

  defp restore_terminal(old_settings) do
    # Show cursor
    IO.write("\e[?25h")
    System.cmd("stty", [old_settings], stderr_to_stdout: true)
  end

  # -- Screen management --

  defp enter_alt_screen(%Session{width: w, height: h}) do
    IO.write("\e[?1049h")
    IO.write("\e[2J\e[H")
    IO.write("\e[8;#{h};#{w}t")
  end

  defp leave_alt_screen do
    IO.write("\e[?1049l")
  end
end
