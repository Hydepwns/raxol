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

  @type window_event_type :: :close | :minimize | :maximize | :restore |
                           :focus | :blur | :move | :resize | :state_change |
                           :show | :hide | :activate | :deactivate |
                           :drag_start | :drag_end | :drop

  @type window_event :: {:window_event, window_event_type(), map()}

  @event_types %{
    "close" => :close,
    "minimize" => :minimize,
    "maximize" => :maximize,
    "restore" => :restore,
    "focus" => :focus,
    "blur" => :blur,
    "move" => :move,
    "resize" => :resize,
    "state_change" => :state_change,
    "show" => :show,
    "hide" => :hide,
    "activate" => :activate,
    "deactivate" => :deactivate,
    "drag_start" => :drag_start,
    "drag_end" => :drag_end,
    "drop" => :drop
  }

  @sequence_handlers %{
    "c" => fn [] -> {:window_event, :close, %{}} end,
    "m" => fn [] -> {:window_event, :minimize, %{}} end,
    "M" => fn [] -> {:window_event, :maximize, %{}} end,
    "r" => fn [] -> {:window_event, :restore, %{}} end,
    "f" => fn [] -> {:window_event, :focus, %{}} end,
    "b" => fn [] -> {:window_event, :blur, %{}} end,
    "v" => fn [x, y] -> {:window_event, :move, %{x: parse_number(x), y: parse_number(y)}} end,
    "z" => fn [width, height] -> {:window_event, :resize, %{width: parse_number(width), height: parse_number(height)}} end,
    "s" => fn [state] -> {:window_event, :state_change, %{state: state}} end,
    "w" => fn [] -> {:window_event, :show, %{}} end,
    "h" => fn [] -> {:window_event, :hide, %{}} end,
    "a" => fn [] -> {:window_event, :activate, %{}} end,
    "d" => fn [] -> {:window_event, :deactivate, %{}} end,
    "D" => fn [x, y] -> {:window_event, :drag_start, %{x: parse_number(x), y: parse_number(y)}} end,
    "E" => fn [x, y] -> {:window_event, :drag_end, %{x: parse_number(x), y: parse_number(y)}} end,
    "p" => fn [x, y] -> {:window_event, :drop, %{x: parse_number(x), y: parse_number(y)}} end
  }

  @event_formatters %{
    close: fn _ -> "\e[?c" end,
    minimize: fn _ -> "\e[?m" end,
    maximize: fn _ -> "\e[?M" end,
    restore: fn _ -> "\e[?r" end,
    focus: fn _ -> "\e[?f" end,
    blur: fn _ -> "\e[?b" end,
    move: fn %{x: x, y: y} -> "\e[?v;#{x};#{y}" end,
    resize: fn %{width: width, height: height} -> "\e[?z;#{width};#{height}" end,
    state_change: fn %{state: state} -> "\e[?s;#{state}" end,
    show: fn _ -> "\e[?w" end,
    hide: fn _ -> "\e[?h" end,
    activate: fn _ -> "\e[?a" end,
    deactivate: fn _ -> "\e[?d" end,
    drag_start: fn %{x: x, y: y} -> "\e[?D;#{x};#{y}" end,
    drag_end: fn %{x: x, y: y} -> "\e[?E;#{x};#{y}" end,
    drop: fn %{x: x, y: y} -> "\e[?p;#{x};#{y}" end
  }

  @doc """
  Processes a window event sequence and returns the corresponding event.
  """
  @spec process_sequence(String.t(), list(String.t())) :: window_event() | nil
  def process_sequence(sequence, params) do
    try do
      case Map.get(@sequence_handlers, sequence) do
        nil -> nil
        handler -> handler.(params)
      end
    rescue
      e ->
        Monitor.record_error(sequence, "Window event error: #{inspect(e)}", %{
          params: params,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        nil
    end
  end

  @doc """
  Formats a window event into an ANSI sequence.
  """
  @spec format_event(window_event()) :: String.t()
  def format_event({:window_event, type, params}) do
    case Map.get(@event_formatters, type) do
      nil -> ""
      formatter -> formatter.(params)
    end
  end
  def format_event(_), do: ""

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

  defp parse_number(string, default \\ 0) do
    case Integer.parse(string) do
      {number, _} -> number
      :error -> default
    end
  end
end
