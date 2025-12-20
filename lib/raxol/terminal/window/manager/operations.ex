defmodule Raxol.Terminal.Window.Manager.Operations do
  @moduledoc """
  Operations module for window management functionality.
  Handles all the complex logic for window creation, updates, and hierarchy management.
  """

  alias Raxol.Terminal.{Config, Window, Window.Registry}

  @type window_id :: String.t()
  @type window_state :: :active | :inactive | :minimized | :maximized

  @doc """
  Creates a window with configuration.
  """
  @spec create_window_with_config(Config.t()) ::
          {:ok, Window.t()} | {:error, term()}
  def create_window_with_config(%Config{} = config) do
    window = Window.new(config)

    case Registry.register_window(window) do
      {:ok, window_id} ->
        # Get the full window with ID from registry
        case Registry.get_window(window_id) do
          {:ok, full_window} -> {:ok, full_window}
          {:error, reason} -> {:error, {:get_window_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:register_failed, reason}}
    end
  end

  @doc """
  Gets a window by ID with proper error handling.
  """
  @spec get_window_by_id(window_id()) ::
          {:ok, Window.t()} | {:error, :not_found}
  def get_window_by_id(id) do
    case Registry.get_window(id) do
      {:ok, window} -> {:ok, window}
      {:error, _} -> {:error, :not_found}
    end
  end

  @doc """
  Destroys a window by ID.
  """
  @spec destroy_window_by_id(window_id()) :: :ok | {:error, :not_found}
  def destroy_window_by_id(id) do
    case Registry.unregister_window(id) do
      :ok -> :ok
      {:error, _} -> {:error, :not_found}
    end
  end

  @doc """
  Lists all windows.
  """
  @spec list_all_windows() :: {:ok, [Window.t()]}
  def list_all_windows do
    # Registry.list_windows always returns {:ok, windows}
    Registry.list_windows()
  end

  @doc """
  Sets the active window.
  """
  @spec set_active_window(window_id()) :: :ok | {:error, :not_found}
  def set_active_window(id) do
    case get_window_by_id(id) do
      {:ok, _window} ->
        Registry.set_active_window(id)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets the active window.
  """
  @spec get_active_window() :: {:ok, Window.t()} | {:error, :not_found}
  def get_active_window do
    case Registry.get_active_window() do
      {:ok, window} -> {:ok, window}
      {:error, _} -> {:error, :not_found}
    end
  end

  @doc """
  Updates a window property.
  """
  @spec update_window_property(window_id(), atom(), any()) ::
          {:ok, Window.t()} | {:error, :not_found}
  def update_window_property(id, property, value) do
    case get_window_by_id(id) do
      {:ok, _window} ->
        case Registry.update_window(id, %{property => value}) do
          {:ok, updated_window} ->
            {:ok, updated_window}

          {:error, _} ->
            {:error, :not_found}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Creates a child window.
  """
  @spec create_child_window(window_id(), Config.t()) ::
          {:ok, Window.t()} | {:error, :not_found}
  def create_child_window(parent_id, %Config{} = config) do
    case get_window_by_id(parent_id) do
      {:ok, parent_window} ->
        case create_window_with_config(config) do
          {:ok, child_window} ->
            setup_parent_child_relationship(parent_window, child_window)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets child windows for a parent.
  """
  @spec get_child_windows(window_id()) ::
          {:ok, [Window.t()]} | {:error, :not_found}
  def get_child_windows(parent_id) do
    case get_window_by_id(parent_id) do
      {:ok, parent_window} ->
        children = fetch_child_windows(parent_window.children)
        {:ok, children}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets the parent window for a child.
  """
  @spec get_parent_window(window_id()) ::
          {:ok, Window.t()} | {:error, :no_parent}
  def get_parent_window(child_id) do
    case get_window_by_id(child_id) do
      {:ok, child_window} ->
        case child_window.parent do
          nil -> {:error, :no_parent}
          parent_id -> get_window_by_id(parent_id)
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  # Private helper functions

  @spec setup_parent_child_relationship(Window.t(), Window.t()) ::
          {:ok, Window.t()} | {:error, :update_failed}
  defp setup_parent_child_relationship(parent_window, child_window) do
    # Update child with parent reference
    case Registry.update_window(child_window.id, %{parent: parent_window.id}) do
      {:ok, updated_child} ->
        # Update parent with child reference
        case Registry.update_window(parent_window.id, %{
               children: [child_window.id | parent_window.children]
             }) do
          {:ok, _updated_parent} -> {:ok, updated_child}
          {:error, _} -> {:error, :update_failed}
        end

      {:error, _} ->
        {:error, :update_failed}
    end
  end

  @spec fetch_child_windows([window_id()]) :: [Window.t()]
  defp fetch_child_windows(child_ids) do
    child_ids
    |> Enum.map(&get_window_by_id/1)
    |> Enum.filter(fn
      {:ok, _window} -> true
      {:error, _} -> false
    end)
    |> Enum.map(fn {:ok, window} -> window end)
  end
end
