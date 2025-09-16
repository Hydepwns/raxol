defmodule Raxol.Core.Behaviours.StateManager do
  @moduledoc """
  Behaviour for state management systems.

  Defines the callbacks that state manager implementations must provide
  for managing application and component state.
  """

  @type state :: term()
  @type state_key :: term()
  @type state_value :: term()
  @type plugin_id :: String.t()
  @type plugin_module :: module()
  @type plugin_config :: map()

  @doc """
  Initializes state management system.

  ## Returns
  - `{:ok, initial_state}` on success
  - `{:error, reason}` on failure
  """
  @callback init() :: {:ok, state()} | {:error, term()}

  @doc """
  Gets a value from the state.

  ## Parameters
  - state: Current state
  - key: Key to retrieve

  ## Returns
  - `{:ok, value}` if key exists
  - `{:error, :not_found}` if key doesn't exist
  """
  @callback get_state(state(), state_key()) ::
              {:ok, state_value()} | {:error, :not_found}

  @doc """
  Sets a value in the state.

  ## Parameters
  - state: Current state
  - key: Key to set
  - value: Value to set

  ## Returns
  - `{:ok, new_state}` on success
  - `{:error, reason}` on failure
  """
  @callback set_state(state(), state_key(), state_value()) ::
              {:ok, state()} | {:error, term()}

  @doc """
  Updates state using a function.

  ## Parameters
  - state: Current state
  - key: Key to update
  - update_fn: Function to apply to the current value

  ## Returns
  - `{:ok, new_state}` on success
  - `{:error, reason}` on failure
  """
  @callback update_state(state(), state_key(), (state_value() -> state_value())) ::
              {:ok, state()} | {:error, term()}

  @doc """
  Removes a key from the state.

  ## Parameters
  - state: Current state
  - key: Key to remove

  ## Returns
  - `{:ok, new_state}` on success
  """
  @callback delete_state(state(), state_key()) :: {:ok, state()}

  @doc """
  Initializes plugin-specific state.

  ## Parameters
  - plugin_module: The plugin module
  - config: Plugin configuration

  ## Returns
  - `{:ok, initial_plugin_state}` on success
  - `{:error, reason}` on failure
  """
  @callback initialize_plugin_state(plugin_module(), plugin_config()) ::
              {:ok, state()} | {:error, term()}

  @doc """
  Updates plugin state (legacy interface).

  ## Parameters
  - plugin_id: Plugin identifier
  - state: Plugin state
  - config: Plugin configuration

  ## Returns
  - `{:ok, updated_state}` on success
  - `{:error, reason}` on failure
  """
  @callback update_plugin_state_legacy(plugin_id(), state(), plugin_config()) ::
              {:ok, state()} | {:error, term()}

  @doc """
  Cleans up state management resources.

  ## Parameters
  - state: Current state

  ## Returns
  - :ok on successful cleanup
  """
  @callback cleanup(state()) :: :ok
end
