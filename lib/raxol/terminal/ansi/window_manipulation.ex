defmodule Raxol.Terminal.ANSI.WindowManipulation do
  @moduledoc """
  Handles window manipulation sequences for terminal control.
  Supports window resizing, positioning, and state management.

  ## Features

  * Window resizing
  * Window positioning
  * Window state (minimize, maximize, restore)
  * Window title management
  * Window icon management
  * Window stacking order
  * Window transparency
  * Window focus management
  * Window borders and decorations
  * Window events
  * Window state persistence
  * Window layout management
  * Window group management
  * Window animations
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.ANSI.Monitor

  @type window_state :: :normal | :minimized | :maximized | :fullscreen
  @type window_position :: {non_neg_integer(), non_neg_integer()}
  @type window_size :: {non_neg_integer(), non_neg_integer()}
  @type window_border_style :: :none | :single | :double | :rounded | :custom
  @type window_event :: {:window_resize, window_size()} |
                       {:window_move, window_position()} |
                       {:window_state, window_state()} |
                       {:window_title, String.t()} |
                       {:window_icon, String.t()} |
                       {:window_focus, boolean()} |
                       {:window_border, window_border_style()} |
                       {:window_border_color, {non_neg_integer(), non_neg_integer(), non_neg_integer()}} |
                       {:window_border_width, non_neg_integer()} |
                       {:window_border_radius, non_neg_integer()} |
                       {:window_shadow, boolean()} |
                       {:window_shadow_color, {non_neg_integer(), non_neg_integer(), non_neg_integer()}} |
                       {:window_shadow_blur, non_neg_integer()} |
                       {:window_shadow_offset, {non_neg_integer(), non_neg_integer()}}

  @window_states %{
    "0" => :normal,
    "1" => :minimized,
    "2" => :maximized,
    "3" => :fullscreen
  }

  @border_styles %{
    "0" => :none,
    "1" => :single,
    "2" => :double,
    "3" => :rounded,
    "4" => :custom
  }

  @event_handlers %{
    window_resize: &format_resize/1,
    window_move: &format_move/1,
    window_state: &format_state/1,
    window_title: &format_title/1,
    window_icon: &format_icon/1,
    window_focus: &format_focus/1,
    window_stack: &format_stack/1,
    window_transparency: &format_transparency/1,
    window_border: &format_border_style/1,
    window_border_color: &format_border_color/1,
    window_border_width: &format_border_width/1,
    window_border_radius: &format_border_radius/1,
    window_shadow: &format_shadow/1,
    window_shadow_color: &format_shadow_color/1,
    window_shadow_blur: &format_shadow_blur/1,
    window_shadow_offset: &format_shadow_offset/1
  }

  @sequence_handlers %{
    "4" => &handle_resize/1,
    "3" => &handle_move/1,
    "t" => &handle_state/1,
    "l" => &handle_title/1,
    "L" => &handle_icon/1,
    "f" => &handle_focus/1,
    "r" => &handle_stack/1,
    "T" => &handle_transparency/1,
    "b" => &handle_border_style/1,
    "B" => &handle_border_color/1,
    "w" => &handle_border_width/1,
    "R" => &handle_border_radius/1,
    "s" => &handle_shadow/1,
    "S" => &handle_shadow_color/1,
    "u" => &handle_shadow_blur/1,
    "o" => &handle_shadow_offset/1
  }

  @doc """
  Processes a window manipulation sequence and returns the corresponding event.
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
        Monitor.record_error(sequence, "Window manipulation error: #{inspect(e)}", %{
          params: params,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        nil
    end
  end

  defp handle_resize([height, width]), do: {:window_resize, {parse_number(width), parse_number(height)}}
  defp handle_move([x, y]), do: {:window_move, {parse_number(x), parse_number(y)}}
  defp handle_state([state]), do: Map.get(@window_states, state) && {:window_state, @window_states[state]}
  defp handle_title([title]), do: {:window_title, title}
  defp handle_icon([icon]), do: {:window_icon, icon}
  defp handle_focus(["1"]), do: {:window_focus, true}
  defp handle_focus(["0"]), do: {:window_focus, false}
  defp handle_stack([position]), do: {:window_stack, parse_number(position)}
  defp handle_transparency([alpha]), do: {:window_transparency, parse_number(alpha) / 100}
  defp handle_border_style([style]), do: Map.get(@border_styles, style) && {:window_border, @border_styles[style]}
  defp handle_border_color([r, g, b]), do: {:window_border_color, {parse_number(r), parse_number(g), parse_number(b)}}
  defp handle_border_width([width]), do: {:window_border_width, parse_number(width)}
  defp handle_border_radius([radius]), do: {:window_border_radius, parse_number(radius)}
  defp handle_shadow(["1"]), do: {:window_shadow, true}
  defp handle_shadow(["0"]), do: {:window_shadow, false}
  defp handle_shadow_color([r, g, b]), do: {:window_shadow_color, {parse_number(r), parse_number(g), parse_number(b)}}
  defp handle_shadow_blur([blur]), do: {:window_shadow_blur, parse_number(blur)}
  defp handle_shadow_offset([x, y]), do: {:window_shadow_offset, {parse_number(x), parse_number(y)}}

  @doc """
  Formats a window event into an ANSI sequence.
  """
  @spec format_event(window_event()) :: String.t()
  def format_event({event_type, params}) do
    case Map.get(@event_handlers, event_type) do
      nil -> ""
      handler -> handler.(params)
    end
  end
  def format_event(_), do: ""

  defp format_resize({width, height}) do
    "\e[4;#{height};#{width}t"
  end
  defp format_move({x, y}), do: "\e[3;#{x};#{y}t"
  defp format_state(state) do
    code = Enum.find_value(@window_states, fn {code, s} -> if s == state, do: code end)
    "\e[#{code}t"
  end
  defp format_title(title), do: "\e]l#{title}\e\\"
  defp format_icon(icon), do: "\e]L#{icon}\e\\"
  defp format_focus(true), do: "\e[1f"
  defp format_focus(false), do: "\e[0f"
  defp format_stack(position), do: "\e[#{position}r"
  defp format_transparency(alpha), do: "\e[#{trunc(alpha * 100)}T"
  defp format_border_style(style) do
    code = Enum.find_value(@border_styles, fn {code, s} -> if s == style, do: code end)
    "\e[#{code}b"
  end
  defp format_border_color({r, g, b}), do: "\e[#{r};#{g};#{b}B"
  defp format_border_width(width), do: "\e[#{width}w"
  defp format_border_radius(radius), do: "\e[#{radius}R"
  defp format_shadow(true), do: "\e[1s"
  defp format_shadow(false), do: "\e[0s"
  defp format_shadow_color({r, g, b}), do: "\e[#{r};#{g};#{b}S"
  defp format_shadow_blur(blur), do: "\e[#{blur}u"
  defp format_shadow_offset({x, y}), do: "\e[#{x};#{y}o"

  @doc """
  Enables window manipulation mode.
  """
  @spec enable_window_manipulation() :: String.t()
  def enable_window_manipulation do
    "\e[?62h"
  end

  @doc """
  Disables window manipulation mode.
  """
  @spec disable_window_manipulation() :: String.t()
  def disable_window_manipulation do
    "\e[?62l"
  end

  defp parse_number(string, default \\ 0) do
    case Integer.parse(string) do
      {number, _} -> number
      :error -> default
    end
  end
end
