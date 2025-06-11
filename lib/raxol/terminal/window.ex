defmodule Raxol.Terminal.Window do
  @moduledoc """
  Represents a terminal window with its properties and state.
  """

  alias Raxol.Terminal.{Emulator, Config}

  @type window_state :: :active | :inactive | :minimized | :maximized
  @type window_position :: {integer(), integer()}
  @type window_size :: {non_neg_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t(),
          emulator: Emulator.t(),
          config: Config.t(),
          state: window_state(),
          position: window_position(),
          size: window_size(),
          previous_size: window_size() | nil,
          parent: String.t() | nil,
          children: [String.t()]
        }

  defstruct [
    :id,
    title: "Terminal",
    emulator: nil,
    config: nil,
    state: :inactive,
    position: {0, 0},
    size: {80, 24},
    previous_size: nil,
    parent: nil,
    children: []
  ]

  @doc """
  Creates a new window with the given configuration.
  """
  @spec new(Config.t()) :: t()
  def new(%Config{} = config) do
    {width, height} = Config.get_dimensions(config)
    emulator = Emulator.new(width, height)

    %__MODULE__{
      config: config,
      emulator: emulator,
      size: {width, height}
    }
  end

  @doc """
  Creates a new window with custom dimensions.
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height) when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    config = Config.new(width, height)
    new(config)
  end

  @doc """
  Updates the window title.
  """
  @spec set_title(t(), String.t()) :: t()
  def set_title(%__MODULE__{} = window, title) when is_binary(title) do
    %{window | title: title}
  end

  @doc """
  Updates the window position.
  """
  @spec set_position(t(), integer(), integer()) :: t()
  def set_position(%__MODULE__{} = window, x, y) when is_integer(x) and is_integer(y) do
    %{window | position: {x, y}}
  end

  @doc """
  Updates the window size.
  """
  @spec set_size(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_size(%__MODULE__{} = window, width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    # Save current size before updating
    previous_size = window.size

    # Update emulator with new size
    emulator = Emulator.resize(window.emulator, width, height)

    %{window |
      size: {width, height},
      previous_size: previous_size,
      emulator: emulator
    }
  end

  @doc """
  Updates the window state.
  """
  @spec set_state(t(), window_state()) :: t()
  def set_state(%__MODULE__{} = window, state) when state in [:active, :inactive, :minimized, :maximized] do
    %{window | state: state}
  end

  @doc """
  Sets the parent window.
  """
  @spec set_parent(t(), String.t()) :: t()
  def set_parent(%__MODULE__{} = window, parent_id) when is_binary(parent_id) do
    %{window | parent: parent_id}
  end

  @doc """
  Adds a child window.
  """
  @spec add_child(t(), String.t()) :: t()
  def add_child(%__MODULE__{} = window, child_id) when is_binary(child_id) do
    %{window | children: [child_id | window.children]}
  end

  @doc """
  Removes a child window.
  """
  @spec remove_child(t(), String.t()) :: t()
  def remove_child(%__MODULE__{} = window, child_id) when is_binary(child_id) do
    %{window | children: List.delete(window.children, child_id)}
  end

  @doc """
  Restores the previous window size.
  """
  @spec restore_size(t()) :: t()
  def restore_size(%__MODULE__{} = window) do
    case window.previous_size do
      nil -> window
      {width, height} -> set_size(window, width, height)
    end
  end

  @doc """
  Gets the window's current dimensions.
  """
  @spec get_dimensions(t()) :: window_size()
  def get_dimensions(%__MODULE__{} = window) do
    window.size
  end

  @doc """
  Gets the window's current position.
  """
  @spec get_position(t()) :: window_position()
  def get_position(%__MODULE__{} = window) do
    window.position
  end

  @doc """
  Gets the window's current state.
  """
  @spec get_state(t()) :: window_state()
  def get_state(%__MODULE__{} = window) do
    window.state
  end

  @doc """
  Gets the window's child windows.
  """
  @spec get_children(t()) :: [String.t()]
  def get_children(%__MODULE__{} = window) do
    window.children
  end

  @doc """
  Gets the window's parent window.
  """
  @spec get_parent(t()) :: String.t() | nil
  def get_parent(%__MODULE__{} = window) do
    window.parent
  end
end
