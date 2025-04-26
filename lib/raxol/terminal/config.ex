defmodule Raxol.Terminal.Config do
  @moduledoc """
  Terminal configuration system.

  This module is the main entry point for terminal configuration, providing
  a simplified interface to the underlying configuration modules.
  """

  alias Raxol.Terminal.Config.{
    Schema,
    Validation,
    Persistence,
    Defaults,
    Capabilities,
    Profiles,
    Application
  }

  # Schema-related functions

  @doc """
  Returns the configuration schema.

  ## Returns

  A map defining the structure and types for all configuration options.
  """
  defdelegate config_schema, to: Schema

  @doc """
  Returns the type information for a specific configuration path.

  ## Parameters

  * `path` - A list of keys representing the path to the configuration value

  ## Returns

  A tuple with type information or nil if the path doesn't exist
  """
  defdelegate get_type(path), to: Schema

  # Validation-related functions

  @doc """
  Validates a complete terminal configuration.

  ## Parameters

  * `config` - The configuration to validate

  ## Returns

  `{:ok, validated_config}` or `{:error, reason}`
  """
  defdelegate validate_config(config), to: Validation

  @doc """
  Validates a specific configuration value against its schema.

  ## Parameters

  * `path` - A list of keys representing the path to the configuration value
  * `value` - The value to validate

  ## Returns

  `{:ok, validated_value}` or `{:error, reason}`
  """
  defdelegate validate_value(path, value), to: Validation

  # Persistence-related functions

  @doc """
  Loads terminal configuration from the default path.

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  defdelegate load_config, to: Persistence

  @doc """
  Loads terminal configuration from the specified path.

  ## Parameters

  * `path` - The file path to load from

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  defdelegate load_config(path), to: Persistence

  @doc """
  Saves terminal configuration to the default path.

  ## Parameters

  * `config` - The configuration to save

  ## Returns

  `:ok` or `{:error, reason}`
  """
  defdelegate save_config(config), to: Persistence

  @doc """
  Saves terminal configuration to the specified path.

  ## Parameters

  * `config` - The configuration to save
  * `path` - The file path to save to

  ## Returns

  `:ok` or `{:error, reason}`
  """
  defdelegate save_config(config, path), to: Persistence

  # Default-related functions

  @doc """
  Generates a default configuration based on terminal capabilities.

  ## Returns

  A map containing default configuration values for all settings.
  """
  defdelegate generate_default_config, to: Defaults

  # Capability-related functions

  @doc """
  Detects terminal capabilities based on the environment.

  ## Returns

  A map of detected capabilities.
  """
  defdelegate detect_capabilities, to: Capabilities

  @doc """
  Creates an optimized configuration based on detected capabilities.

  ## Returns

  An optimized configuration for the current terminal.
  """
  defdelegate optimized_config, to: Capabilities

  # Profile-related functions

  @doc """
  Lists all available terminal configuration profiles.

  ## Returns

  A list of profile names.
  """
  defdelegate list_profiles, to: Profiles

  @doc """
  Loads a specific terminal configuration profile.

  ## Parameters

  * `name` - The name of the profile to load

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  defdelegate load_profile(name), to: Profiles

  @doc """
  Saves the current configuration as a profile.

  ## Parameters

  * `name` - The name of the profile to save
  * `config` - The configuration to save

  ## Returns

  `:ok` or `{:error, reason}`
  """
  defdelegate save_profile(name, config), to: Profiles

  # Application-related functions

  @doc """
  Applies a configuration to the terminal.

  ## Parameters

  * `config` - The configuration to apply
  * `terminal_pid` - The PID of the terminal process (optional)

  ## Returns

  `{:ok, applied_config}` or `{:error, reason}`
  """
  defdelegate apply_config(config, terminal_pid \\ nil), to: Application

  @doc """
  Applies a partial configuration update to the terminal.

  ## Parameters

  * `partial_config` - The partial configuration to apply
  * `terminal_pid` - The PID of the terminal process (optional)

  ## Returns

  `{:ok, updated_config}` or `{:error, reason}`
  """
  defdelegate apply_partial_config(partial_config, terminal_pid \\ nil),
    to: Application

  @doc """
  Gets the current terminal configuration.

  ## Parameters

  * `terminal_pid` - The PID of the terminal process (optional)

  ## Returns

  The current terminal configuration.
  """
  defdelegate get_current_config(terminal_pid \\ nil), to: Application

  @doc """
  Resets terminal configuration to default values.

  ## Parameters

  * `terminal_pid` - The PID of the terminal process (optional)
  * `optimize` - Whether to optimize for detected capabilities (default: true)

  ## Returns

  `{:ok, default_config}` or `{:error, reason}`
  """
  defdelegate reset_config(terminal_pid \\ nil, optimize \\ true),
    to: Application
end
