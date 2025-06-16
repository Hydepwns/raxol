defmodule Raxol.Terminal.Window.Manager do
  @moduledoc """
  Manages terminal window properties and operations.
  """

  defstruct [
    title: "",
    icon_name: "",
    size: {80, 24},  # {width, height}
    position: {0, 0},  # {x, y}
    stacking_order: :normal,  # :normal, :above, :below
    saved_size: nil,
    saved_position: nil
  ]

  @type window_size :: {pos_integer(), pos_integer()}
  @type window_position :: {integer(), integer()}
  @type stacking_order :: :normal | :above | :below

  @type t :: %__MODULE__{
    title: String.t(),
    icon_name: String.t(),
    size: window_size(),
    position: window_position(),
    stacking_order: stacking_order(),
    saved_size: window_size() | nil,
    saved_position: window_position() | nil
  }

  @doc """
  Creates a new window manager instance.
  """
  def new(opts \\ []) do
    %__MODULE__{
      size: Keyword.get(opts, :size, {80, 24}),
      position: Keyword.get(opts, :position, {0, 0})
    }
  end

  @doc """
  Sets the window title.
  """
  def set_window_title(%__MODULE__{} = state, title) when is_binary(title) do
    %{state | title: title}
  end

  @doc """
  Sets the window icon name.
  """
  def set_icon_name(%__MODULE__{} = state, name) when is_binary(name) do
    %{state | icon_name: name}
  end

  @doc """
  Sets the window size.
  """
  def set_window_size(%__MODULE__{} = state, width, height)
      when is_integer(width) and width > 0
      and is_integer(height) and height > 0 do
    %{state | size: {width, height}}
  end

  @doc """
  Sets the window position.
  """
  def set_window_position(%__MODULE__{} = state, x, y)
      when is_integer(x) and is_integer(y) do
    %{state | position: {x, y}}
  end

  @doc """
  Sets the window stacking order.
  """
  def set_stacking_order(%__MODULE__{} = state, order)
      when order in [:normal, :above, :below] do
    %{state | stacking_order: order}
  end

  @doc """
  Gets the current window state.
  """
  def get_window_state(%__MODULE__{} = state) do
    %{
      title: state.title,
      icon_name: state.icon_name,
      size: state.size,
      position: state.position,
      stacking_order: state.stacking_order
    }
  end

  @doc """
  Saves the current window size for later restoration.
  """
  def save_window_size(%__MODULE__{} = state) do
    %{state | saved_size: state.size}
  end

  @doc """
  Restores the previously saved window size.
  """
  def restore_window_size(%__MODULE__{} = state) do
    case state.saved_size do
      nil -> state
      size -> %{state | size: size}
    end
  end

  @doc """
  Gets the window width.
  """
  def get_width(%__MODULE__{} = state) do
    elem(state.size, 0)
  end

  @doc """
  Gets the window height.
  """
  def get_height(%__MODULE__{} = state) do
    elem(state.size, 1)
  end

  @doc """
  Gets the window position.
  """
  def get_position(%__MODULE__{} = state) do
    state.position
  end

  @doc """
  Gets the window title.
  """
  def get_title(%__MODULE__{} = state) do
    state.title
  end

  @doc """
  Gets the window icon name.
  """
  def get_icon_name(%__MODULE__{} = state) do
    state.icon_name
  end

  @doc """
  Gets the window stacking order.
  """
  def get_stacking_order(%__MODULE__{} = state) do
    state.stacking_order
  end
end
