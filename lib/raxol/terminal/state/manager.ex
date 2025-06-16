defmodule Raxol.Terminal.State.Manager do
  @moduledoc """
  Manages the overall state of the terminal, including mode settings,
  cursor state, and terminal dimensions.
  """

  defstruct [
    # Terminal dimensions
    rows: 24,
    cols: 80,
    scrollback_size: 1000,

    # Cursor state
    cursor_x: 0,
    cursor_y: 0,
    cursor_visible: true,
    cursor_style: :block,

    # Terminal modes
    modes: %{
      insert: false,
      replace: false,
      origin: false,
      auto_wrap: true,
      auto_repeat: true,
      interlacing: false,
      new_line: false,
      cursor_visible: true,
      cursor_blink: true,
      reverse_video: false,
      screen: true,
      scroll: true,
      keyboard: true,
      mouse: false,
      mouse_protocol: :normal,
      mouse_protocol_encoding: :utf8,
      mouse_protocol_buttons: :all,
      mouse_protocol_motion: :all,
      mouse_protocol_sgr: false,
      mouse_protocol_urxvt: false,
      mouse_protocol_pixels: false,
      mouse_protocol_utf8: false,
      mouse_protocol_sgr_pixels: false,
      mouse_protocol_urxvt_pixels: false,
      mouse_protocol_sgr_utf8: false,
      mouse_protocol_urxvt_utf8: false,
      mouse_protocol_sgr_pixels_utf8: false,
      mouse_protocol_urxvt_pixels_utf8: false
    },

    # Saved cursor state
    saved_cursor: nil,

    # Terminal state
    title: "",
    icon_name: "",
    bell_enabled: true,
    bell_volume: 100,
    bell_pitch: 440,
    bell_duration: 200,
    bell_style: :normal,
    bell_visible: true,
    bell_audible: true,
    bell_urgent: false,
    bell_urgent_style: :normal,
    bell_urgent_visible: true,
    bell_urgent_audible: true,
    bell_urgent_duration: 200,
    bell_urgent_pitch: 440,
    bell_urgent_volume: 100,
    bell_urgent_count: 0,
    bell_urgent_max: 3,
    bell_urgent_timeout: 1000,
    bell_urgent_last: nil,
    bell_urgent_active: false
  ]

  @type mode :: atom()
  @type mode_value :: boolean()
  @type cursor_style :: :block | :underline | :bar
  @type bell_style :: :normal | :visible | :audible | :urgent
  @type bell_urgent_style :: :normal | :visible | :audible | :urgent

  @type t :: %__MODULE__{
    rows: non_neg_integer(),
    cols: non_neg_integer(),
    scrollback_size: non_neg_integer(),
    cursor_x: non_neg_integer(),
    cursor_y: non_neg_integer(),
    cursor_visible: boolean(),
    cursor_style: cursor_style(),
    modes: %{mode() => mode_value()},
    saved_cursor: {non_neg_integer(), non_neg_integer()} | nil,
    title: String.t(),
    icon_name: String.t(),
    bell_enabled: boolean(),
    bell_volume: non_neg_integer(),
    bell_pitch: non_neg_integer(),
    bell_duration: non_neg_integer(),
    bell_style: bell_style(),
    bell_visible: boolean(),
    bell_audible: boolean(),
    bell_urgent: boolean(),
    bell_urgent_style: bell_urgent_style(),
    bell_urgent_visible: boolean(),
    bell_urgent_audible: boolean(),
    bell_urgent_duration: non_neg_integer(),
    bell_urgent_pitch: non_neg_integer(),
    bell_urgent_volume: non_neg_integer(),
    bell_urgent_count: non_neg_integer(),
    bell_urgent_max: non_neg_integer(),
    bell_urgent_timeout: non_neg_integer(),
    bell_urgent_last: DateTime.t() | nil,
    bell_urgent_active: boolean()
  }

  @doc """
  Creates a new terminal state manager instance.
  """
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Gets the current terminal dimensions.
  """
  def get_dimensions(%__MODULE__{} = state) do
    {state.rows, state.cols}
  end

  @doc """
  Sets the terminal dimensions.
  """
  def set_dimensions(%__MODULE__{} = state, rows, cols)
      when is_integer(rows) and rows > 0
      and is_integer(cols) and cols > 0 do
    %{state | rows: rows, cols: cols}
  end

  @doc """
  Gets the current cursor position.
  """
  def get_cursor_position(%__MODULE__{} = state) do
    {state.cursor_x, state.cursor_y}
  end

  @doc """
  Sets the cursor position.
  """
  def set_cursor_position(%__MODULE__{} = state, x, y)
      when is_integer(x) and x >= 0
      and is_integer(y) and y >= 0 do
    %{state | cursor_x: x, cursor_y: y}
  end

  @doc """
  Gets the cursor visibility state.
  """
  def get_cursor_visibility(%__MODULE__{} = state) do
    state.cursor_visible
  end

  @doc """
  Sets the cursor visibility.
  """
  def set_cursor_visibility(%__MODULE__{} = state, visible) when is_boolean(visible) do
    %{state | cursor_visible: visible}
  end

  @doc """
  Gets the cursor style.
  """
  def get_cursor_style(%__MODULE__{} = state) do
    state.cursor_style
  end

  @doc """
  Sets the cursor style.
  """
  def set_cursor_style(%__MODULE__{} = state, style) when style in [:block, :underline, :bar] do
    %{state | cursor_style: style}
  end

  @doc """
  Gets the value of a terminal mode.
  """
  def get_mode(%__MODULE__{} = state, mode) when is_atom(mode) do
    Map.get(state.modes, mode)
  end

  @doc """
  Sets a terminal mode value.
  """
  def set_mode(%__MODULE__{} = state, mode, value)
      when is_atom(mode) and is_boolean(value) do
    %{state | modes: Map.put(state.modes, mode, value)}
  end

  @doc """
  Saves the current cursor state.
  """
  def save_cursor(%__MODULE__{} = state) do
    %{state | saved_cursor: {state.cursor_x, state.cursor_y}}
  end

  @doc """
  Restores the saved cursor state.
  """
  def restore_cursor(%__MODULE__{} = state) do
    case state.saved_cursor do
      nil -> state
      {x, y} -> %{state | cursor_x: x, cursor_y: y}
    end
  end

  @doc """
  Gets the terminal title.
  """
  def get_title(%__MODULE__{} = state) do
    state.title
  end

  @doc """
  Sets the terminal title.
  """
  def set_title(%__MODULE__{} = state, title) when is_binary(title) do
    %{state | title: title}
  end

  @doc """
  Gets the terminal icon name.
  """
  def get_icon_name(%__MODULE__{} = state) do
    state.icon_name
  end

  @doc """
  Sets the terminal icon name.
  """
  def set_icon_name(%__MODULE__{} = state, name) when is_binary(name) do
    %{state | icon_name: name}
  end

  @doc """
  Triggers the terminal bell.
  """
  def trigger_bell(%__MODULE__{} = state) do
    if state.bell_enabled do
      # Handle bell triggering logic here
      state
    else
      state
    end
  end

  @doc """
  Resets the terminal state to default values.
  """
  def reset(%__MODULE__{} = state) do
    %{state |
      cursor_x: 0,
      cursor_y: 0,
      cursor_visible: true,
      cursor_style: :block,
      modes: %{
        insert: false,
        replace: false,
        origin: false,
        auto_wrap: true,
        auto_repeat: true,
        interlacing: false,
        new_line: false,
        cursor_visible: true,
        cursor_blink: true,
        reverse_video: false,
        screen: true,
        scroll: true,
        keyboard: true,
        mouse: false
      },
      saved_cursor: nil,
      title: "",
      icon_name: ""
    }
  end
end
