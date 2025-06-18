defmodule Raxol.Terminal.Config.EnvironmentAdapterBehaviour do
  @moduledoc """
  Defines the behaviour for terminal environment configuration.

  This behaviour is responsible for:
  - Managing terminal environment variables
  - Handling terminal configuration
  - Providing environment-specific settings
  - Adapting to different terminal environments
  """

  @doc """
  Gets the value of an environment variable.
  """
  @callback get_env(key :: String.t()) :: {:ok, String.t()} | {:error, any()}

  @doc """
  Sets an environment variable.
  """
  @callback set_env(key :: String.t(), value :: String.t()) ::
              :ok | {:error, any()}

  @doc """
  Gets all environment variables.
  """
  @callback get_all_env() :: {:ok, map()} | {:error, any()}

  @doc """
  Gets terminal-specific configuration.
  """
  @callback get_terminal_config() :: {:ok, map()} | {:error, any()}

  @doc """
  Updates terminal configuration.
  """
  @callback update_terminal_config(config :: map()) :: :ok | {:error, any()}

  @doc """
  Gets the current terminal type.
  """
  @callback get_terminal_type() :: {:ok, String.t()} | {:error, any()}

  @doc """
  Checks if a specific terminal feature is supported.
  """
  @callback supports_feature?(feature :: atom()) :: boolean()
end
