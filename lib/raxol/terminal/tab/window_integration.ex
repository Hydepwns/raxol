defmodule Raxol.Terminal.Tab.WindowIntegration do
  @moduledoc """
  Integration module for managing tabs and their associated windows.
  """

  @type t :: %{tabs: map()}

  @doc """
  Creates a window for an existing tab.
  """
  @spec create_window_for_tab(t(), String.t(), map(), map()) ::
          {:ok, String.t(), t(), map()} | {:error, term()}
  def create_window_for_tab(
        tab_manager,
        window_manager,
        tab_id,
        window_config
      ) do
    case get_tab_config(tab_manager, tab_id) do
      {:ok, tab_config} ->
        window_id = generate_window_id()
        updated_tab_config = Map.put(tab_config, :window_id, window_id)

        updated_tab_manager =
          Map.put(
            tab_manager,
            :tabs,
            Map.put(tab_manager.tabs || %{}, tab_id, updated_tab_config)
          )

        {:ok, window_id, updated_tab_manager, window_manager}

      {:error, :not_found} ->
        {:error, :tab_not_found}
    end
  end

  @doc """
  Creates a window for an existing tab (3-arity version).
  """
  @spec create_window_for_tab(t(), String.t(), map()) ::
          {:ok, String.t(), t(), map()} | {:error, term()}
  def create_window_for_tab(tab_manager, window_manager, tab_id) do
    create_window_for_tab(tab_manager, window_manager, tab_id, %{})
  end

  @doc """
  Destroys the window for an existing tab.
  """
  @spec destroy_window_for_tab(t(), String.t(), map()) ::
          {:ok, t(), map()} | {:error, term()}
  def destroy_window_for_tab(tab_manager, window_manager, tab_id) do
    case get_tab_config(tab_manager, tab_id) do
      {:ok, tab_config} ->
        updated_tab_config = Map.put(tab_config, :window_id, nil)

        updated_tab_manager =
          Map.put(
            tab_manager,
            :tabs,
            Map.put(tab_manager.tabs || %{}, tab_id, updated_tab_config)
          )

        {:ok, updated_tab_manager, window_manager}

      {:error, :not_found} ->
        {:error, :tab_not_found}
    end
  end

  @doc """
  Switches to an existing tab and its window.
  """
  @spec switch_to_tab(t(), map(), String.t()) ::
          {:ok, t(), map()} | {:error, term()}
  def switch_to_tab(tab_manager, window_manager, tab_id) do
    case get_tab_config(tab_manager, tab_id) do
      {:ok, _tab_config} ->
        updated_tab_manager = Map.put(tab_manager, :active_tab, tab_id)
        {:ok, updated_tab_manager, window_manager}

      {:error, :not_found} ->
        {:error, :tab_not_found}
    end
  end

  @doc """
  Gets the window ID for an existing tab.
  """
  @spec get_window_for_tab(t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def get_window_for_tab(tab_manager, tab_id) do
    case get_tab_config(tab_manager, tab_id) do
      {:ok, tab_config} ->
        {:ok, Map.get(tab_config, :window_id)}

      {:error, :not_found} ->
        {:error, :tab_not_found}
    end
  end

  @doc """
  Updates the window configuration for an existing tab.
  """
  @spec update_window_for_tab(t(), String.t(), map(), map()) ::
          {:ok, t(), map()} | {:error, term()}
  def update_window_for_tab(
        tab_manager,
        window_manager,
        tab_id,
        window_config
      ) do
    case get_tab_config(tab_manager, tab_id) do
      {:ok, tab_config} ->
        # For now, just return the managers unchanged
        # In a real implementation, this would update the window configuration
        {:ok, tab_manager, window_manager}

      {:error, :not_found} ->
        {:error, :tab_not_found}
    end
  end

  # Private helper functions
  defp get_tab_config(tab_manager, tab_id) do
    case Map.get(tab_manager.tabs || %{}, tab_id) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  defp generate_window_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
