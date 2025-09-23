defmodule Raxol.Terminal.Window do
  @moduledoc """
  Represents a terminal window with its properties and state.

  This module provides functionality for managing terminal windows, including:
  * Window creation and configuration
  * State management (active, inactive, minimized, maximized)
  * Size and position control
  * Parent-child window relationships
  * Terminal emulator integration

  ## Window States

  * `:active` - Window is currently focused
  * `:inactive` - Window is not focused
  * `:minimized` - Window is minimized
  * `:maximized` - Window is maximized

  ## Usage

  ```elixir
  # Create a new window with default size
  window = Window.new(Config.new())

  # Create a window with custom dimensions
  window = Window.new(100, 50)

  # Update window title
  {:ok, window} = Window.set_title(window, "My Terminal")
  ```
  """

  alias Raxol.Terminal.{Emulator, Config}
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @type window_state :: :active | :inactive | :minimized | :maximized
  @type window_position :: {integer(), integer()}
  @type window_size :: {integer(), integer()}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t(),
          icon_name: String.t(),
          font: String.t(),
          cursor_shape: String.t(),
          clipboard: String.t(),
          emulator: EmulatorStruct.t(),
          config: Config.t(),
          state: window_state(),
          position: window_position(),
          size: window_size(),
          width: integer(),
          height: integer(),
          previous_size: window_size() | nil,
          parent: String.t() | nil,
          children: [String.t()]
        }

  defstruct [
    :id,
    title: "Terminal",
    icon_name: "Terminal",
    font: "monospace",
    cursor_shape: "block",
    clipboard: "",
    emulator: nil,
    config: nil,
    state: :inactive,
    position: {0, 0},
    size: {80, 24},
    width: 80,
    height: 24,
    previous_size: nil,
    parent: nil,
    children: []
  ]

  @doc """
  Creates a new window with the given configuration.

  ## Parameters

    * `config` - Terminal configuration (Config.t())

  ## Returns

    * A new window instance with the specified configuration

  ## Examples

      iex> config = Config.new()
      iex> window = Window.new(config)
      iex> window.size
      {80, 24}
  """
  @spec new(Config.t()) :: t()
  def new(config) do
    {width, height} = Config.get_dimensions(config)
    emulator = EmulatorStruct.new(width, height)

    %__MODULE__{
      config: config,
      emulator: emulator,
      size: {width, height},
      width: width,
      height: height
    }
  end

  @doc """
  Creates a new window with custom dimensions.

  ## Parameters

    * `width` - Window width in characters (positive integer)
    * `height` - Window height in characters (positive integer)

  ## Returns

    * A new window instance with the specified dimensions

  ## Examples

      iex> window = Window.new(100, 50)
      iex> window.size
      {100, 50}
  """
  @spec new(integer(), integer()) :: t()
  def new(width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    config = Config.new(width, height)
    new(config)
  end

  @doc """
  Updates the window title.

  ## Parameters

    * `window` - The window to update
    * `title` - New window title

  ## Returns

    * `{:ok, updated_window}` - Title updated successfully
    * `{:error, reason}` - Failed to update title

  ## Examples

      iex> window = Window.new(80, 24)
      iex> {:ok, window} = Window.set_title(window, "My Terminal")
      iex> window.title
      "My Terminal"
  """
  @spec set_title(t(), String.t()) :: {:ok, t()}
  def set_title(%__MODULE__{} = window, title) when is_binary(title) do
    {:ok, %{window | title: title}}
  end

  @doc """
  Updates the window position.
  """
  @spec set_position(t(), integer(), integer()) :: {:ok, t()}
  def set_position(%__MODULE__{} = window, x, y)
      when is_integer(x) and is_integer(y) do
    {:ok, %{window | position: {x, y}}}
  end

  @doc """
  Updates the window size.
  """
  @spec set_size(t(), non_neg_integer(), non_neg_integer()) :: {:ok, t()}
  def set_size(%__MODULE__{} = window, width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    previous_size = window.size
    emulator = Emulator.resize(window.emulator, width, height)

    {:ok,
     %{
       window
       | size: {width, height},
         width: width,
         height: height,
         previous_size: previous_size,
         emulator: emulator
     }}
  end

  @doc """
  Updates the window state.
  """
  @spec set_state(t(), window_state()) :: {:ok, t()}
  def set_state(%__MODULE__{} = window, state)
      when state in [:active, :inactive, :minimized, :maximized] do
    {:ok, %{window | state: state}}
  end

  @doc """
  Sets the parent window.
  """
  @spec set_parent(t(), String.t()) :: {:ok, t()}
  def set_parent(%__MODULE__{} = window, parent_id) when is_binary(parent_id) do
    {:ok, %{window | parent: parent_id}}
  end

  @doc """
  Adds a child window.
  """
  @spec add_child(t(), String.t()) :: {:ok, t()}
  def add_child(%__MODULE__{} = window, child_id) when is_binary(child_id) do
    {:ok, %{window | children: [child_id | window.children]}}
  end

  @doc """
  Removes a child window.
  """
  @spec remove_child(t(), String.t()) :: {:ok, t()}
  def remove_child(%__MODULE__{} = window, child_id) when is_binary(child_id) do
    {:ok, %{window | children: List.delete(window.children, child_id)}}
  end

  @doc """
  Restores the previous window size.
  """
  @spec restore_size(t()) :: {:ok, t()}
  def restore_size(%__MODULE__{} = window) do
    case window.previous_size do
      nil -> {:ok, window}
      {width, height} -> set_size(window, width, height)
    end
  end

  @doc """
  Gets the window's current dimensions.
  """
  @spec get_dimensions(t()) :: {:ok, window_size()}
  def get_dimensions(%__MODULE__{} = window) do
    {:ok, window.size}
  end

  @doc """
  Gets the window's current position.
  """
  @spec get_position(t()) :: {:ok, window_position()}
  def get_position(%__MODULE__{} = window) do
    {:ok, window.position}
  end

  @doc """
  Gets the window's current state.
  """
  @spec get_state(t()) :: {:ok, window_state()}
  def get_state(%__MODULE__{} = window) do
    {:ok, window.state}
  end

  @doc """
  Gets the window's child windows.
  """
  @spec get_children(t()) :: {:ok, [String.t()]}
  def get_children(%__MODULE__{} = window) do
    {:ok, window.children}
  end

  @doc """
  Gets the window's parent window.
  """
  @spec get_parent(t()) :: {:ok, String.t() | nil}
  def get_parent(%__MODULE__{} = window) do
    {:ok, window.parent}
  end

  @doc """
  Updates the window's icon name.
  """
  @spec set_icon_name(t(), String.t()) :: {:ok, t()}
  def set_icon_name(%__MODULE__{} = window, name) when is_binary(name) do
    {:ok, %{window | icon_name: name}}
  end

  @doc """
  Updates the window's font.
  """
  @spec set_font(t(), String.t()) :: {:ok, t()}
  def set_font(%__MODULE__{} = window, font) when is_binary(font) do
    {:ok, %{window | font: font}}
  end

  @doc """
  Updates the window's cursor shape.
  """
  @spec set_cursor_shape(t(), String.t()) :: t()
  def set_cursor_shape(%__MODULE__{} = window, shape) when is_binary(shape) do
    %{window | cursor_shape: shape}
  end

  @doc """
  Updates the window's clipboard content.
  """
  @spec set_clipboard(t(), String.t()) :: t()
  def set_clipboard(%__MODULE__{} = window, content) when is_binary(content) do
    %{window | clipboard: content}
  end

  @doc """
  Gets the window's clipboard content.
  """
  @spec get_clipboard(t()) :: String.t()
  def get_clipboard(%__MODULE__{} = window) do
    window.clipboard
  end

  @doc """
  Gets the window's icon name.
  """
  @spec get_icon_name(t()) :: String.t()
  def get_icon_name(%__MODULE__{} = window) do
    window.icon_name
  end

  @doc """
  Gets the window's font.
  """
  @spec get_font(t()) :: String.t()
  def get_font(%__MODULE__{} = window) do
    window.font
  end

  @doc """
  Gets the window's cursor shape.
  """
  @spec get_cursor_shape(t()) :: String.t()
  def get_cursor_shape(%__MODULE__{} = window) do
    window.cursor_shape
  end

  @doc """
  Gets the window's working directory.
  """
  @spec get_working_directory(t()) :: String.t()
  def get_working_directory(%__MODULE__{} = _window) do
    File.cwd!()
  end

  @doc """
  Sets the window's working directory.
  """
  @spec set_working_directory(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def set_working_directory(%__MODULE__{}, _dir) do
    {:error, :working_directory_not_supported}
  end

  @doc """
  Gets a hyperlink by ID.
  """
  @spec get_hyperlink(t(), String.t()) :: String.t() | nil
  def get_hyperlink(%__MODULE__{}, _id) do
    nil
  end

  @doc """
  Sets a hyperlink with the given ID and URL.
  """
  @spec set_hyperlink(t(), String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def set_hyperlink(%__MODULE__{}, _id, _url) do
    {:error, :hyperlinks_not_supported}
  end

  @doc """
  Clears a hyperlink by ID.
  """
  @spec clear_hyperlink(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def clear_hyperlink(%__MODULE__{}, _id) do
    {:error, :hyperlinks_not_supported}
  end

  @doc """
  Gets the window's current size.
  """
  @spec get_size(t()) :: window_size()
  def get_size(%__MODULE__{} = window) do
    window.size
  end
end
