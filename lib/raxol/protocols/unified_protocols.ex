defmodule Raxol.Protocols.UnifiedProtocols do
  @moduledoc """
  Unified protocol definitions for Raxol core functionality.
  Consolidates multiple protocol definitions to reduce duplication and improve consistency.
  """

  defprotocol Component do
    @moduledoc """
    Protocol for renderable UI components.
    Combines functionality from Renderable, Styleable, and EventHandler protocols.
    """

    @doc """
    Renders the component to terminal output with the given options.
    """
    @spec render(t(), map()) :: String.t()
    def render(component, opts \\ %{})

    @doc """
    Handles events sent to the component.
    """
    @spec handle_event(t(), map(), any()) :: {:ok | :unhandled, t(), any()}
    def handle_event(component, event, state)

    @doc """
    Applies styling to the component.
    """
    @spec apply_style(t(), map()) :: t()
    def apply_style(component, style)

    @doc """
    Gets the component's metadata (dimensions, capabilities, etc.).
    """
    @spec get_metadata(t()) :: map()
    def get_metadata(component)

    @doc """
    Validates the component's configuration.
    """
    @spec validate(t()) :: :ok | {:error, [String.t()]}
    def validate(component)
  end

  defprotocol Serializable do
    @moduledoc """
    Protocol for serializing and deserializing data structures.
    Handles conversion to/from various formats (JSON, TOML, binary).
    """

    @doc """
    Serializes the data to the specified format.
    """
    @spec serialize(t(), :json | :toml | :binary | :erlang_term) :: {:ok, binary()} | {:error, any()}
    def serialize(data, format \\ :json)

    @doc """
    Deserializes data from the specified format.
    """
    @spec deserialize(binary(), :json | :toml | :binary | :erlang_term, module()) :: {:ok, t()} | {:error, any()}
    def deserialize(data, format, target_type)

    @doc """
    Gets the serialization schema for validation.
    """
    @spec get_schema(t()) :: map()
    def get_schema(data)
  end

  defprotocol BufferOperations do
    @moduledoc """
    Protocol for buffer operations across different buffer types.
    Provides unified interface for screen buffers, text buffers, etc.
    """

    @doc """
    Writes data to the buffer at the specified position.
    """
    @spec write(t(), {integer(), integer()}, any()) :: t()
    def write(buffer, position, data)

    @doc """
    Reads data from the buffer at the specified position.
    """
    @spec read(t(), {integer(), integer()}) :: any()
    def read(buffer, position)

    @doc """
    Clears the buffer or a region of the buffer.
    """
    @spec clear(t(), :all | {integer(), integer(), integer(), integer()}) :: t()
    def clear(buffer, region \\ :all)

    @doc """
    Gets the buffer dimensions.
    """
    @spec get_dimensions(t()) :: {integer(), integer()}
    def get_dimensions(buffer)

    @doc """
    Resizes the buffer to new dimensions.
    """
    @spec resize(t(), integer(), integer()) :: t()
    def resize(buffer, width, height)

    @doc """
    Scrolls the buffer in the specified direction.
    """
    @spec scroll(t(), :up | :down | :left | :right, integer()) :: t()
    def scroll(buffer, direction, amount)
  end

  defprotocol Configurable do
    @moduledoc """
    Protocol for configurable modules and components.
    Handles configuration loading, validation, and persistence.
    """

    @doc """
    Gets the current configuration.
    """
    @spec get_config(t()) :: map()
    def get_config(configurable)

    @doc """
    Sets the configuration, validating it first.
    """
    @spec set_config(t(), map()) :: {:ok, t()} | {:error, [String.t()]}
    def set_config(configurable, config)

    @doc """
    Validates the configuration.
    """
    @spec validate_config(t(), map()) :: :ok | {:error, [String.t()]}
    def validate_config(configurable, config)

    @doc """
    Gets the default configuration.
    """
    @spec get_default_config(t()) :: map()
    def get_default_config(configurable)

    @doc """
    Merges configuration with defaults.
    """
    @spec merge_config(t(), map()) :: map()
    def merge_config(configurable, config)
  end

  defprotocol Lifecycle do
    @moduledoc """
    Protocol for managing component/module lifecycle.
    Handles initialization, startup, shutdown, and cleanup.
    """

    @doc """
    Initializes the component/module with given options.
    """
    @spec initialize(t(), keyword()) :: {:ok, t()} | {:error, any()}
    def initialize(component, opts \\ [])

    @doc """
    Starts the component/module.
    """
    @spec start(t()) :: {:ok, t()} | {:error, any()}
    def start(component)

    @doc """
    Stops the component/module.
    """
    @spec stop(t()) :: {:ok, t()} | {:error, any()}
    def stop(component)

    @doc """
    Restarts the component/module.
    """
    @spec restart(t()) :: {:ok, t()} | {:error, any()}
    def restart(component)

    @doc """
    Cleans up resources used by the component/module.
    """
    @spec cleanup(t()) :: :ok
    def cleanup(component)

    @doc """
    Gets the current lifecycle state.
    """
    @spec get_state(t()) :: :initialized | :starting | :running | :stopping | :stopped | :error
    def get_state(component)
  end
end

# Convenience module for importing all protocols
defmodule Raxol.Protocols do
  @moduledoc """
  Convenience module for importing all unified protocols.
  """

  alias Raxol.Protocols.UnifiedProtocols

  defdelegate render(component, opts), to: UnifiedProtocols.Component
  defdelegate handle_event(component, event, state), to: UnifiedProtocols.Component
  defdelegate apply_style(component, style), to: UnifiedProtocols.Component
  defdelegate get_metadata(component), to: UnifiedProtocols.Component
  defdelegate validate(component), to: UnifiedProtocols.Component

  defdelegate serialize(data, format), to: UnifiedProtocols.Serializable
  defdelegate deserialize(data, format, target_type), to: UnifiedProtocols.Serializable
  defdelegate get_schema(data), to: UnifiedProtocols.Serializable

  defdelegate write(buffer, position, data), to: UnifiedProtocols.BufferOperations
  defdelegate read(buffer, position), to: UnifiedProtocols.BufferOperations
  defdelegate clear(buffer, region), to: UnifiedProtocols.BufferOperations
  defdelegate get_dimensions(buffer), to: UnifiedProtocols.BufferOperations
  defdelegate resize(buffer, width, height), to: UnifiedProtocols.BufferOperations
  defdelegate scroll(buffer, direction, amount), to: UnifiedProtocols.BufferOperations

  defdelegate get_config(configurable), to: UnifiedProtocols.Configurable
  defdelegate set_config(configurable, config), to: UnifiedProtocols.Configurable
  defdelegate validate_config(configurable, config), to: UnifiedProtocols.Configurable
  defdelegate get_default_config(configurable), to: UnifiedProtocols.Configurable
  defdelegate merge_config(configurable, config), to: UnifiedProtocols.Configurable

  defdelegate initialize(component, opts), to: UnifiedProtocols.Lifecycle
  defdelegate start(component), to: UnifiedProtocols.Lifecycle
  defdelegate stop(component), to: UnifiedProtocols.Lifecycle
  defdelegate restart(component), to: UnifiedProtocols.Lifecycle
  defdelegate cleanup(component), to: UnifiedProtocols.Lifecycle
  defdelegate get_state(component), to: UnifiedProtocols.Lifecycle
end