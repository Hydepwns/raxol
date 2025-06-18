defmodule Raxol.Core.UserPreferences.Behaviour do
  @moduledoc '''
  Defines the behaviour for UserPreferences services.
  '''

  @doc '''
  Gets a user preference value by key path.
  '''
  @callback get(
              key_or_path :: atom() | list(atom()) | String.t(),
              pid_or_name :: GenServer.server() | atom() | nil
            ) :: any()
  @callback get(key_or_path :: atom() | list(atom()) | String.t()) :: any()

  @doc '''
  Sets a user preference value by key path.
  '''
  @callback set(
              key_or_path :: atom() | list(atom()) | String.t(),
              value :: any(),
              pid_or_name :: GenServer.server() | atom() | nil
            ) :: :ok
  @callback set(
              key_or_path :: atom() | list(atom()) | String.t(),
              value :: any()
            ) :: :ok

  @doc '''
  Forces an immediate save of the current preferences.
  '''
  @callback save!(pid_or_name :: GenServer.server() | atom() | nil) ::
              :ok | {:error, any()}
  @callback save!() :: :ok | {:error, any()}

  @doc '''
  Retrieves the entire preferences map.
  '''
  @callback get_all(pid_or_name :: GenServer.server() | atom() | nil) :: map()
  @callback get_all() :: map()
end
