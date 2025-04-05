defmodule Raxol.Plugins.Plugin do
  @moduledoc """
  Defines the behavior for Raxol terminal emulator plugins.
  Plugins can extend the terminal's functionality by implementing this behavior.
  """

  @type t :: %__MODULE__{
    name: String.t(),
    version: String.t(),
    description: String.t(),
    enabled: boolean(),
    config: map(),
    dependencies: list(map()),
    api_version: String.t()
  }

  defstruct [
    :name,
    :version,
    :description,
    :enabled,
    :config,
    :dependencies,
    :api_version
  ]

  @callback init(config :: map()) :: {:ok, t()} | {:error, String.t()}
  @callback handle_input(plugin :: t(), input :: String.t()) :: {:ok, t()} | {:error, String.t()}
  @callback handle_output(plugin :: t(), output :: String.t()) :: {:ok, t()} | {:error, String.t()}
  @callback handle_mouse(plugin :: t(), event :: tuple()) :: {:ok, t()} | {:error, String.t()}
  @callback handle_resize(plugin :: t(), width :: non_neg_integer(), height :: non_neg_integer()) :: {:ok, t()} | {:error, String.t()}
  @callback cleanup(plugin :: t()) :: :ok | {:error, String.t()}
  
  @doc """
  Returns the plugin's dependencies.
  Each dependency is a map with the following keys:
  - name: The name of the plugin
  - version: The version constraint (e.g., ">= 1.0.0")
  - optional: Whether the dependency is optional (default: false)
  """
  @callback get_dependencies() :: list(map())
  
  @doc """
  Returns the plugin's API version.
  This is used to check compatibility with the plugin manager.
  """
  @callback get_api_version() :: String.t()
end 