defmodule Raxol.Terminal.Tab.Manager do
  @moduledoc """
  Manages terminal tabs and their associated sessions.
  This module handles the creation, deletion, and switching of terminal tabs,
  as well as maintaining tab state and configuration.
  """

  alias Raxol.Terminal.{Session, Window.Manager}

  @type tab_id :: String.t()
  @type tab_state :: :active | :inactive | :hidden
  @type tab_config :: %{
    title: String.t(),
    working_directory: String.t(),
    command: String.t() | nil,
    state: tab_state,
    window_id: String.t() | nil
  }

  @type t :: %__MODULE__{
    tabs: %{tab_id() => tab_config()},
    active_tab: tab_id() | nil,
    next_tab_id: non_neg_integer()
  }

  defstruct tabs: %{}, active_tab: nil, next_tab_id: 1

  @doc """
  Creates a new tab manager instance.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new tab with the given configuration.

  ## Parameters

  * `manager` - The tab manager instance
  * `config` - The tab configuration (optional)

  ## Returns

  `{:ok, tab_id, updated_manager}` on success
  `{:error, reason}` on failure
  """
  @spec create_tab(t(), tab_config() | nil) :: {:ok, tab_id(), t()} | {:error, term()}
  def create_tab(manager, config \\ %{}) do
    tab_id = generate_tab_id(manager)
    default_config = %{
      title: "Tab #{tab_id}",
      working_directory: System.cwd!(),
      command: nil,
      state: :inactive,
      window_id: nil
    }

    config = Map.merge(default_config, config)

    updated_manager = %{manager |
      tabs: Map.put(manager.tabs, tab_id, config),
      next_tab_id: manager.next_tab_id + 1
    }

    {:ok, tab_id, updated_manager}
  end

  @doc """
  Deletes a tab by its ID.

  ## Parameters

  * `manager` - The tab manager instance
  * `tab_id` - The ID of the tab to delete

  ## Returns

  `{:ok, updated_manager}` on success
  `{:error, :tab_not_found}` if the tab doesn't exist
  """
  @spec delete_tab(t(), tab_id()) :: {:ok, t()} | {:error, :tab_not_found}
  def delete_tab(manager, tab_id) do
    case Map.has_key?(manager.tabs, tab_id) do
      true ->
        updated_manager = %{manager |
          tabs: Map.delete(manager.tabs, tab_id),
          active_tab: if(manager.active_tab == tab_id, do: nil, else: manager.active_tab)
        }
        {:ok, updated_manager}
      false ->
        {:error, :tab_not_found}
    end
  end

  @doc """
  Switches to a different tab.

  ## Parameters

  * `manager` - The tab manager instance
  * `tab_id` - The ID of the tab to switch to

  ## Returns

  `{:ok, updated_manager}` on success
  `{:error, :tab_not_found}` if the tab doesn't exist
  """
  @spec switch_tab(t(), tab_id()) :: {:ok, t()} | {:error, :tab_not_found}
  def switch_tab(manager, tab_id) do
    case Map.has_key?(manager.tabs, tab_id) do
      true ->
        updated_manager = %{manager | active_tab: tab_id}
        {:ok, updated_manager}
      false ->
        {:error, :tab_not_found}
    end
  end

  @doc """
  Gets the configuration for a specific tab.

  ## Parameters

  * `manager` - The tab manager instance
  * `tab_id` - The ID of the tab to get

  ## Returns

  `{:ok, config}` if the tab exists
  `{:error, :tab_not_found}` if the tab doesn't exist
  """
  @spec get_tab_config(t(), tab_id()) :: {:ok, tab_config()} | {:error, :tab_not_found}
  def get_tab_config(manager, tab_id) do
    case Map.get(manager.tabs, tab_id) do
      nil -> {:error, :tab_not_found}
      config -> {:ok, config}
    end
  end

  @doc """
  Updates the configuration for a specific tab.

  ## Parameters

  * `manager` - The tab manager instance
  * `tab_id` - The ID of the tab to update
  * `config_updates` - The configuration updates to apply

  ## Returns

  `{:ok, updated_manager}` on success
  `{:error, :tab_not_found}` if the tab doesn't exist
  """
  @spec update_tab_config(t(), tab_id(), map()) :: {:ok, t()} | {:error, :tab_not_found}
  def update_tab_config(manager, tab_id, config_updates) do
    case Map.get(manager.tabs, tab_id) do
      nil ->
        {:error, :tab_not_found}
      current_config ->
        updated_config = Map.merge(current_config, config_updates)
        updated_manager = %{manager |
          tabs: Map.put(manager.tabs, tab_id, updated_config)
        }
        {:ok, updated_manager}
    end
  end

  @doc """
  Lists all tabs and their configurations.

  ## Parameters

  * `manager` - The tab manager instance

  ## Returns

  A map of tab IDs to their configurations
  """
  @spec list_tabs(t()) :: %{tab_id() => tab_config()}
  def list_tabs(manager), do: manager.tabs

  @doc """
  Gets the currently active tab ID.

  ## Parameters

  * `manager` - The tab manager instance

  ## Returns

  The active tab ID, or nil if no tab is active
  """
  @spec get_active_tab(t()) :: tab_id() | nil
  def get_active_tab(manager), do: manager.active_tab

  # Private helper functions

  defp generate_tab_id(manager) do
    "tab_#{manager.next_tab_id}"
  end
end
