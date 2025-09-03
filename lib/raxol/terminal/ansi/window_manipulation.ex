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
  @type window_event ::
          {:window_resize, window_size()}
          | {:window_move, window_position()}
          | {:window_state, window_state()}
          | {:window_title, String.t()}
          | {:window_icon, String.t()}
          | {:window_focus, boolean()}
          | {:window_border, window_border_style()}
          | {:window_border_color,
             {non_neg_integer(), non_neg_integer(), non_neg_integer()}}
          | {:window_border_width, non_neg_integer()}
          | {:window_border_radius, non_neg_integer()}
          | {:window_shadow, boolean()}
          | {:window_shadow_color,
             {non_neg_integer(), non_neg_integer(), non_neg_integer()}}
          | {:window_shadow_blur, non_neg_integer()}
          | {:window_shadow_offset, {non_neg_integer(), non_neg_integer()}}

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
    window_resize: &Raxol.Terminal.ANSI.WindowManipulation.format_resize/1,
    window_move: &__MODULE__.format_move/1,
    window_state: &__MODULE__.format_state/1,
    window_title: &__MODULE__.format_title/1,
    window_icon: &__MODULE__.format_icon/1,
    window_focus: &__MODULE__.format_focus/1,
    window_stack: &__MODULE__.format_stack/1,
    window_transparency: &__MODULE__.format_transparency/1,
    window_border: &__MODULE__.format_border_style/1,
    window_border_color: &__MODULE__.format_border_color/1,
    window_border_width: &__MODULE__.format_border_width/1,
    window_border_radius: &__MODULE__.format_border_radius/1,
    window_shadow: &__MODULE__.format_shadow/1,
    window_shadow_color: &__MODULE__.format_shadow_color/1,
    window_shadow_blur: &__MODULE__.format_shadow_blur/1,
    window_shadow_offset: &__MODULE__.format_shadow_offset/1
  }

  @sequence_handlers %{
    "4" => &__MODULE__.handle_resize/1,
    "3" => &__MODULE__.handle_move/1,
    "t" => &__MODULE__.handle_state/1,
    "l" => &__MODULE__.handle_title/1,
    "L" => &__MODULE__.handle_icon/1,
    "f" => &__MODULE__.handle_focus/1,
    "r" => &__MODULE__.handle_stack/1,
    "T" => &__MODULE__.handle_transparency/1,
    "b" => &__MODULE__.handle_border_style/1,
    "B" => &__MODULE__.handle_border_color/1,
    "w" => &__MODULE__.handle_border_width/1,
    "R" => &__MODULE__.handle_border_radius/1,
    "s" => &__MODULE__.handle_shadow/1,
    "S" => &__MODULE__.handle_shadow_color/1,
    "u" => &__MODULE__.handle_shadow_blur/1,
    "o" => &__MODULE__.handle_shadow_offset/1
  }

  @doc """
  Creates a new window manipulation state with default values.
  """
  def new() do
    %{
      position: {0, 0},
      size: {80, 24},
      state: :normal,
      title: "",
      icon: "",
      focused: true,
      border_style: :single,
      border_color: {0, 0, 0},
      border_width: 1,
      border_radius: 0,
      shadow: false,
      shadow_color: {0, 0, 0},
      shadow_blur: 0,
      shadow_offset: {0, 0},
      transparency: 1.0
    }
  end

  @doc """
  Processes a window manipulation sequence and returns the corresponding event.
  """
  @spec process_sequence(String.t(), list(String.t())) :: window_event() | nil
  def process_sequence(sequence, params) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
      case Map.get(@sequence_handlers, sequence) do
        nil -> nil
        handler -> handler.(params)
      end
    end) do
      {:ok, result} -> result
      {:error, reason} ->
        Monitor.record_error(
          sequence,
          "Window manipulation error: #{inspect(reason)}",
          %{
            params: params
          }
        )
        nil
    end
  end

  def handle_resize([height, width]),
    do: {:window_resize, {parse_number(width), parse_number(height)}}

  def handle_move([x, y]),
    do: {:window_move, {parse_number(x), parse_number(y)}}

  def handle_state([state]),
    do: Map.get(@window_states, state) && {:window_state, @window_states[state]}

  def handle_title([title]), do: {:window_title, title}
  def handle_icon([icon]), do: {:window_icon, icon}
  def handle_focus(["1"]), do: {:window_focus, true}
  def handle_focus(["0"]), do: {:window_focus, false}
  def handle_stack([position]), do: {:window_stack, parse_number(position)}

  def handle_transparency([alpha]),
    do: {:window_transparency, parse_number(alpha) / 100}

  def handle_border_style([style]),
    do:
      Map.get(@border_styles, style) && {:window_border, @border_styles[style]}

  def handle_border_color([r, g, b]),
    do:
      {:window_border_color,
       {parse_number(r), parse_number(g), parse_number(b)}}

  def handle_border_width([width]),
    do: {:window_border_width, parse_number(width)}

  def handle_border_radius([radius]),
    do: {:window_border_radius, parse_number(radius)}

  def handle_shadow(["1"]), do: {:window_shadow, true}
  def handle_shadow(["0"]), do: {:window_shadow, false}

  def handle_shadow_color([r, g, b]),
    do:
      {:window_shadow_color,
       {parse_number(r), parse_number(g), parse_number(b)}}

  def handle_shadow_blur([blur]), do: {:window_shadow_blur, parse_number(blur)}

  def handle_shadow_offset([x, y]),
    do: {:window_shadow_offset, {parse_number(x), parse_number(y)}}

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

  def format_resize({width, height}) do
    "\e[4;#{height};#{width}t"
  end

  def format_resize(%{width: width, height: height}) do
    "\e[4;#{height};#{width}t"
  end

  def format_move({x, y}), do: "\e[3;#{x};#{y}t"

  def format_state(state) do
    code =
      Enum.find_value(@window_states, fn {code, s} ->
        if s == state, do: code
      end)

    "\e[#{code}t"
  end

  def format_title(title), do: "\e]l#{title}\e\\"
  def format_icon(icon), do: "\e]L#{icon}\e\\"
  def format_focus(true), do: "\e[1f"
  def format_focus(false), do: "\e[0f"
  def format_stack(position), do: "\e[#{position}r"
  def format_transparency(alpha), do: "\e[#{trunc(alpha * 100)}T"

  def format_border_style(style) do
    code =
      Enum.find_value(@border_styles, fn {code, s} ->
        if s == style, do: code
      end)

    "\e[#{code}b"
  end

  def format_border_color({r, g, b}), do: "\e[#{r};#{g};#{b}B"
  def format_border_width(width), do: "\e[#{width}w"
  def format_border_radius(radius), do: "\e[#{radius}R"
  def format_shadow(true), do: "\e[1s"
  def format_shadow(false), do: "\e[0s"
  def format_shadow_color({r, g, b}), do: "\e[#{r};#{g};#{b}S"
  def format_shadow_blur(blur), do: "\e[#{blur}u"
  def format_shadow_offset({x, y}), do: "\e[#{x};#{y}o"

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

  @doc """
  Formats a mouse click event into an ANSI sequence.
  """
  @spec mouse_click(atom(), non_neg_integer(), non_neg_integer()) :: String.t()
  def mouse_click(button, x, y) do
    button_code =
      case button do
        :left -> 0
        :middle -> 1
        :right -> 2
        :wheel_up -> 64
        :wheel_down -> 65
        _ -> 0
      end

    "\e[M#{button_code + 32}#{x + 32}#{y + 32}"
  end

  @doc """
  Formats a mouse drag event into an ANSI sequence.
  """
  @spec mouse_drag(atom(), non_neg_integer(), non_neg_integer()) :: String.t()
  def mouse_drag(button, x, y) do
    button_code =
      case button do
        :left -> 0
        :middle -> 1
        :right -> 2
        _ -> 0
      end

    "\e[M#{button_code + 32 + 32}#{x + 32}#{y + 32}"
  end

  @doc """
  Formats a mouse release event into an ANSI sequence.
  """
  @spec mouse_release(atom(), non_neg_integer(), non_neg_integer()) ::
          String.t()
  def mouse_release(button, x, y) do
    button_code =
      case button do
        :left -> 0
        :middle -> 1
        :right -> 2
        _ -> 0
      end

    "\e[M#{button_code + 32 + 64}#{x + 32}#{y + 32}"
  end

  # Map of keys to their press ANSI sequences
  @key_press_sequences %{
    "F1" => "\eOP",
    "F2" => "\eOQ",
    "F3" => "\eOR",
    "F4" => "\eOS",
    "F5" => "\e[15~",
    "F6" => "\e[17~",
    "F7" => "\e[18~",
    "F8" => "\e[19~",
    "F9" => "\e[20~",
    "F10" => "\e[21~",
    "F11" => "\e[23~",
    "F12" => "\e[24~",
    "Home" => "\e[H",
    "End" => "\e[F",
    "Insert" => "\e[2~",
    "Delete" => "\e[3~",
    "PageUp" => "\e[5~",
    "PageDown" => "\e[6~",
    "Up" => "\e[A",
    "Down" => "\e[B",
    "Right" => "\e[C",
    "Left" => "\e[D"
  }

  @doc """
  Formats a key press event into an ANSI sequence.
  """
  @spec key_press(String.t()) :: String.t()
  def key_press(key) do
    Map.get(@key_press_sequences, key, key)
  end

  # Map of keys to their release ANSI sequences
  @key_release_sequences %{
    "F1" => "\e[1;2P",
    "F2" => "\e[1;2Q",
    "F3" => "\e[1;2R",
    "F4" => "\e[1;2S",
    "F5" => "\e[15;2~",
    "F6" => "\e[17;2~",
    "F7" => "\e[18;2~",
    "F8" => "\e[19;2~",
    "F9" => "\e[20;2~",
    "F10" => "\e[21;2~",
    "F11" => "\e[23;2~",
    "F12" => "\e[24;2~",
    "Home" => "\e[1;2H",
    "End" => "\e[1;2F",
    "Insert" => "\e[2;2~",
    "Delete" => "\e[3;2~",
    "PageUp" => "\e[5;2~",
    "PageDown" => "\e[6;2~",
    "Up" => "\e[1;2A",
    "Down" => "\e[1;2B",
    "Right" => "\e[1;2C",
    "Left" => "\e[1;2D"
  }

  @doc """
  Formats a key release event into an ANSI sequence.
  """
  @spec key_release(String.t()) :: String.t()
  def key_release(key) do
    Map.get(@key_release_sequences, key, key)
  end

  @doc """
  Formats a focus gain event into an ANSI sequence.
  """
  @spec focus_gain() :: String.t()
  def focus_gain, do: "\e[I"

  @doc """
  Formats a focus loss event into an ANSI sequence.
  """
  @spec focus_loss() :: String.t()
  def focus_loss, do: "\e[O"

  defp parse_number(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_number(num) when is_integer(num), do: num
  defp parse_number(_), do: 0

  @doc """
  Clears the entire screen.
  """
  @spec clear_screen() :: String.t()
  def clear_screen, do: "\e[2J"

  @doc """
  Moves the cursor to the specified position.
  """
  @spec move_cursor(integer(), integer()) :: String.t()
  def move_cursor(x, y), do: "\e[#{y};#{x}H"

  @doc """
  Sets the window title.
  """
  @spec set_title(String.t()) :: String.t()
  def set_title(title), do: "\e]0;#{title}\a"

  @doc """
  Sets the window icon name.
  """
  @spec set_icon_name(String.t()) :: String.t()
  def set_icon_name(name), do: "\e]1;#{name}\a"

  @doc """
  Sets the window mode.
  """
  @spec set_mode(String.t()) :: String.t()
  def set_mode(mode), do: "\e[#{mode}h"

  @doc """
  Sets the window position.
  """
  @spec set_position(non_neg_integer(), non_neg_integer()) :: String.t()
  def set_position(x, y), do: "\e[3;#{x};#{y}t"
end
