defmodule Raxol.Terminal.ANSI.WindowEvents do
  @moduledoc """
  Handles window events for terminal control.
  Supports window close, minimize, maximize, restore, and other window events.

  ## Features

  * Window close events
  * Window minimize/maximize events
  * Window focus events
  * Window move events
  * Window resize events
  * Window state change events
  * Window visibility events
  * Window activation events
  * Window drag events
  * Window drop events
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.ANSI.Monitor
  alias Raxol.Terminal.ANSI.WindowManipulation

  @type window_event_type ::
          :close
          | :minimize
          | :maximize
          | :restore
          | :focus
          | :blur
          | :move
          | :resize
          | :state_change
          | :show
          | :hide
          | :activate
          | :deactivate
          | :drag_start
          | :drag_end
          | :drop

  @type window_event :: {:window_event, window_event_type(), map()}

  @doc """
  Processes a window event sequence and returns the corresponding event.
  """
  @spec process_sequence(String.t(), list(String.t())) :: window_event() | nil
  def process_sequence(sequence, params) do
    try do
      case get_sequence_handler(sequence) do
        nil -> nil
        handler -> handler.(params)
      end
    rescue
      e ->
        handle_sequence_error(sequence, params, e, __STACKTRACE__)
    end
  end

  defp get_sequence_handler(sequence) do
    Map.get(sequence_handlers(), sequence)
  end

  defp handle_sequence_error(sequence, params, error, stacktrace) do
    try do
      Monitor.record_error(sequence, "Window event error: #{inspect(error)}", %{
        params: params,
        stacktrace: Exception.format_stacktrace(stacktrace)
      })
    rescue
      e ->
        Monitor.record_error(
          sequence,
          "Error recording window event error: #{inspect(e)}",
          %{
            original_error: inspect(error),
            params: params,
            stacktrace: Exception.format_stacktrace(stacktrace)
          }
        )
    end

    nil
  end

  @doc """
  Formats a window event into an ANSI escape sequence.
  """
  def format_event(event) do
    case event do
      {:window_event, type, params} ->
        case get_event_formatter(type) do
          nil -> nil
          formatter -> formatter.(params)
        end

      _ ->
        nil
    end
  end

  defp get_event_formatter(type) do
    case type do
      type
      when type in [
             :close,
             :minimize,
             :maximize,
             :restore,
             :focus,
             :blur,
             :show,
             :hide,
             :activate,
             :deactivate
           ] ->
        fn _ -> "\e[?#{get_event_code(type)}" end

      :move ->
        fn params -> format_position_event(:move, params) end

      :resize ->
        &format_resize_event/1

      :state_change ->
        &format_state_event/1

      type when type in [:drag_start, :drag_end, :drop] ->
        fn params -> format_position_event(type, params) end

      _ ->
        fn _ -> "" end
    end
  end

  defp format_position_event(event_type, %{x: x, y: y}) do
    event_code = get_event_code(event_type)
    "\e[?#{event_code};#{x};#{y}"
  end

  defp format_resize_event(%{width: width, height: height}),
    do: "\e[?z;#{width};#{height}"

  defp format_state_event(%{state: state}), do: "\e[?s;#{state}"

  defp get_event_code(type) do
    %{
      close: "c",
      minimize: "m",
      maximize: "M",
      restore: "r",
      focus: "f",
      blur: "b",
      show: "w",
      hide: "h",
      activate: "a",
      deactivate: "d",
      move: "v",
      drag_start: "D",
      drag_end: "E",
      drop: "p"
    }[type]
  end

  @doc """
  Enables window event reporting.
  """
  @spec enable_window_events() :: String.t()
  def enable_window_events do
    "\e[?63h"
  end

  @doc """
  Disables window event reporting.
  """
  @spec disable_window_events() :: String.t()
  def disable_window_events do
    "\e[?63l"
  end

  defp parse_number(string), do: parse_number(string, 0)

  defp parse_number(string, default) do
    case Integer.parse(string) do
      {number, _} -> number
      :error -> default
    end
  end

  defp sequence_handlers do
    Map.merge(
      basic_window_handlers(),
      position_based_handlers()
    )
  end

  defp basic_window_handlers do
    %{
      "c" => fn [] -> {:window_event, :close, %{}} end,
      "m" => fn [] -> {:window_event, :minimize, %{}} end,
      "M" => fn [] -> {:window_event, :maximize, %{}} end,
      "r" => fn [] -> {:window_event, :restore, %{}} end,
      "f" => fn [] -> {:window_event, :focus, %{}} end,
      "b" => fn [] -> {:window_event, :blur, %{}} end,
      "s" => fn [state] -> {:window_event, :state_change, %{state: state}} end,
      "w" => fn [] -> {:window_event, :show, %{}} end,
      "h" => fn [] -> {:window_event, :hide, %{}} end,
      "a" => fn [] -> {:window_event, :activate, %{}} end,
      "d" => fn [] -> {:window_event, :deactivate, %{}} end
    }
  end

  defp position_based_handlers do
    %{
      "v" => fn [x, y] -> {:window_event, :move, parse_position(x, y)} end,
      "z" => fn [width, height] ->
        {:window_event, :resize, parse_resize(width, height)}
      end,
      "D" => fn [x, y] -> {:window_event, :drag_start, parse_position(x, y)} end,
      "E" => fn [x, y] -> {:window_event, :drag_end, parse_position(x, y)} end,
      "p" => fn [x, y] -> {:window_event, :drop, parse_position(x, y)} end
    }
  end

  defp parse_position(x, y) do
    %{x: parse_number(x), y: parse_number(y)}
  end

  defp parse_resize(width, height) do
    %{width: parse_number(width), height: parse_number(height)}
  end

  @doc """
  Processes window-related ANSI escape sequences.
  Returns updated emulator state and any commands that need to be executed.
  """
  def process_window_event(emulator_state, event) do
    case event do
      {:resize, w, h} -> handle_resize(emulator_state, w, h)
      {:title, title} -> handle_title_change(emulator_state, title)
      {:icon_name, _name} -> {:ok, emulator_state, []}
      {:position, x, y} -> handle_position_change(emulator_state, x, y)
      _ -> {:error, "Unknown window event: #{inspect(event)}"}
    end
  end

  defp handle_resize(emulator_state, w, h) do
    updated_state = %{emulator_state | width: w, height: h}

    commands = [
      WindowManipulation.clear_screen(),
      WindowManipulation.move_cursor(1, 1)
    ]

    {:ok, updated_state, commands}
  end

  defp handle_title_change(emulator_state, title) do
    updated_state = %{emulator_state | title: title}
    commands = [WindowManipulation.set_title(title)]
    {:ok, updated_state, commands}
  end

  defp handle_position_change(emulator_state, x, y) do
    updated_state = %{emulator_state | position: {x, y}}
    commands = [WindowManipulation.set_position(x, y)]
    {:ok, updated_state, commands}
  end
end
