defmodule Raxol.Terminal.Window.Manager do
  @moduledoc """
  Manages window-related operations for the terminal emulator.
  This module handles window creation, destruction, switching, and state management.
  """

  alias Raxol.Terminal.{Window, Window.Registry}

  @doc """
  Creates a new window.
  """
  @spec create_window(Window.Config.t()) :: {:ok, Window.t()} | {:error, term()}
  def create_window(config) do
    window = Window.new(config)
    Registry.register_window(window)
  end

  @doc """
  Creates a new window with custom dimensions.
  """
  @spec create_window(non_neg_integer(), non_neg_integer()) :: {:ok, Window.t()} | {:error, term()}
  def create_window(width, height) do
    window = Window.new(width, height)
    Registry.register_window(window)
  end

  @doc """
  Destroys a window.
  """
  @spec destroy_window(String.t()) :: :ok | {:error, term()}
  def destroy_window(window_id) do
    Registry.unregister_window(window_id)
  end

  @doc """
  Gets a window by ID.
  """
  @spec get_window(String.t()) :: {:ok, Window.t()} | {:error, term()}
  def get_window(window_id) do
    Registry.get_window(window_id)
  end

  @doc """
  Lists all windows.
  """
  @spec list_windows() :: {:ok, [Window.t()]}
  def list_windows do
    Registry.list_windows()
  end

  @doc """
  Gets the active window.
  """
  @spec get_active_window() :: {:ok, Window.t()} | {:error, term()}
  def get_active_window do
    Registry.get_active_window()
  end

  @doc """
  Sets the active window.
  """
  @spec set_active_window(String.t()) :: :ok | {:error, term()}
  def set_active_window(window_id) do
    Registry.set_active_window(window_id)
  end

  @doc """
  Updates a window's title.
  """
  @spec set_window_title(String.t(), String.t()) :: {:ok, Window.t()} | {:error, term()}
  def set_window_title(window_id, title) do
    with {:ok, window} <- Registry.get_window(window_id) do
      updated_window = Window.set_title(window, title)
      Registry.update_window(window_id, updated_window)
    end
  end

  @doc """
  Updates a window's position.
  """
  @spec set_window_position(String.t(), integer(), integer()) :: {:ok, Window.t()} | {:error, term()}
  def set_window_position(window_id, x, y) do
    with {:ok, window} <- Registry.get_window(window_id) do
      updated_window = Window.set_position(window, x, y)
      Registry.update_window(window_id, updated_window)
    end
  end

  @doc """
  Updates a window's size.
  """
  @spec set_window_size(String.t(), non_neg_integer(), non_neg_integer()) :: {:ok, Window.t()} | {:error, term()}
  def set_window_size(window_id, width, height) do
    with {:ok, window} <- Registry.get_window(window_id) do
      updated_window = Window.set_size(window, width, height)
      Registry.update_window(window_id, updated_window)
    end
  end

  @doc """
  Updates a window's state.
  """
  @spec set_window_state(String.t(), Window.window_state()) :: {:ok, Window.t()} | {:error, term()}
  def set_window_state(window_id, state) do
    with {:ok, window} <- Registry.get_window(window_id) do
      updated_window = Window.set_state(window, state)
      Registry.update_window(window_id, updated_window)
    end
  end

  @doc """
  Creates a child window.
  """
  @spec create_child_window(String.t(), Window.Config.t()) :: {:ok, Window.t()} | {:error, term()}
  def create_child_window(parent_id, config) do
    with {:ok, parent} <- Registry.get_window(parent_id),
         {:ok, child} <- create_window(config) do
      # Update parent-child relationship
      updated_parent = Window.add_child(parent, child.id)
      updated_child = Window.set_parent(child, parent_id)

      Registry.update_window(parent_id, updated_parent)
      Registry.update_window(child.id, updated_child)

      {:ok, child}
    end
  end

  @doc """
  Gets all child windows of a window.
  """
  @spec get_child_windows(String.t()) :: {:ok, [Window.t()]} | {:error, term()}
  def get_child_windows(window_id) do
    with {:ok, window} <- Registry.get_window(window_id) do
      child_ids = Window.get_children(window)
      children = Enum.map(child_ids, &Registry.get_window/1)
      {:ok, Enum.map(children, fn {:ok, child} -> child end)}
    end
  end

  @doc """
  Gets the parent window of a window.
  """
  @spec get_parent_window(String.t()) :: {:ok, Window.t()} | {:error, term()}
  def get_parent_window(window_id) do
    with {:ok, window} <- Registry.get_window(window_id),
         parent_id when not is_nil(parent_id) <- Window.get_parent(window) do
      Registry.get_window(parent_id)
    else
      nil -> {:error, :no_parent}
      error -> error
    end
  end
end
