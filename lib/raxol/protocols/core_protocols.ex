defmodule Raxol.Protocols.CoreProtocols do
  @moduledoc """
  Unified protocol definitions for Raxol core functionality.
  Consolidates multiple protocol definitions to reduce duplication and improve consistency.
  """

  defprotocol Component do
    @moduledoc """
    Protocol for renderable UI components.
    Combines functionality from Renderable, Styleable, and EventHandler protocols.
    """

    @fallback_to_any true

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

    @fallback_to_any true

    @doc """
    Serializes the data to the specified format.
    """
    @spec serialize(t(), :json | :toml | :binary | :erlang_term) ::
            {:ok, binary()} | {:error, any()}
    def serialize(data, format \\ :json)

    @doc """
    Deserializes data from the specified format.
    """
    @spec deserialize(
            binary(),
            :json | :toml | :binary | :erlang_term,
            module()
          ) :: {:ok, t()} | {:error, any()}
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

    @fallback_to_any true

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

    @fallback_to_any true

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

    @fallback_to_any true

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
    @spec get_state(t()) ::
            :initialized | :starting | :running | :stopping | :stopped | :error
    def get_state(component)
  end
end

# Convenience module for importing all protocols
defmodule Raxol.Protocols do
  @moduledoc """
  Convenience module for importing all unified protocols.
  """

  defdelegate render(component, opts),
    to: Raxol.Protocols.CoreProtocols.Component

  defdelegate handle_event(component, event, state),
    to: Raxol.Protocols.CoreProtocols.Component

  defdelegate apply_style(component, style),
    to: Raxol.Protocols.CoreProtocols.Component

  defdelegate get_metadata(component),
    to: Raxol.Protocols.CoreProtocols.Component

  defdelegate validate(component), to: Raxol.Protocols.CoreProtocols.Component

  defdelegate serialize(data, format),
    to: Raxol.Protocols.CoreProtocols.Serializable

  defdelegate deserialize(data, format, target_type),
    to: Raxol.Protocols.CoreProtocols.Serializable

  defdelegate get_schema(data), to: Raxol.Protocols.CoreProtocols.Serializable

  defdelegate write(buffer, position, data),
    to: Raxol.Protocols.CoreProtocols.BufferOperations

  defdelegate read(buffer, position),
    to: Raxol.Protocols.CoreProtocols.BufferOperations

  defdelegate clear(buffer, region),
    to: Raxol.Protocols.CoreProtocols.BufferOperations

  defdelegate get_dimensions(buffer),
    to: Raxol.Protocols.CoreProtocols.BufferOperations

  defdelegate resize(buffer, width, height),
    to: Raxol.Protocols.CoreProtocols.BufferOperations

  defdelegate scroll(buffer, direction, amount),
    to: Raxol.Protocols.CoreProtocols.BufferOperations

  defdelegate get_config(configurable),
    to: Raxol.Protocols.CoreProtocols.Configurable

  defdelegate set_config(configurable, config),
    to: Raxol.Protocols.CoreProtocols.Configurable

  defdelegate validate_config(configurable, config),
    to: Raxol.Protocols.CoreProtocols.Configurable

  defdelegate get_default_config(configurable),
    to: Raxol.Protocols.CoreProtocols.Configurable

  defdelegate merge_config(configurable, config),
    to: Raxol.Protocols.CoreProtocols.Configurable

  defdelegate initialize(component, opts),
    to: Raxol.Protocols.CoreProtocols.Lifecycle

  defdelegate start(component), to: Raxol.Protocols.CoreProtocols.Lifecycle
  defdelegate stop(component), to: Raxol.Protocols.CoreProtocols.Lifecycle
  defdelegate restart(component), to: Raxol.Protocols.CoreProtocols.Lifecycle
  defdelegate cleanup(component), to: Raxol.Protocols.CoreProtocols.Lifecycle
  defdelegate get_state(component), to: Raxol.Protocols.CoreProtocols.Lifecycle
end

# Fallback implementations for Any
defimpl Raxol.Protocols.CoreProtocols.Component, for: Any do
  def render(_component, _opts), do: ""
  def handle_event(_component, _event, state), do: {:unhandled, state, nil}
  def apply_style(component, _style), do: component
  def get_metadata(_component), do: %{}
  def validate(_component), do: :ok
end

defimpl Raxol.Protocols.CoreProtocols.Serializable, for: Any do
  def serialize(_data, _format), do: {:error, :not_serializable}
  def deserialize(_data, _format, _target), do: {:error, :not_deserializable}
  def get_schema(_data), do: %{}
end

defimpl Raxol.Protocols.CoreProtocols.BufferOperations, for: Any do
  def write(buffer, _position, _data), do: buffer
  def read(_buffer, _position), do: nil
  def clear(buffer, _region), do: buffer
  def get_dimensions(_buffer), do: {0, 0}
  def resize(buffer, _width, _height), do: buffer
  def scroll(buffer, _direction, _amount), do: buffer
end

defimpl Raxol.Protocols.CoreProtocols.Configurable, for: Any do
  def get_config(_configurable), do: %{}
  def set_config(configurable, _config), do: {:ok, configurable}
  def validate_config(_configurable, _config), do: :ok
  def get_default_config(_configurable), do: %{}
  def merge_config(_configurable, config), do: config
end

defimpl Raxol.Protocols.CoreProtocols.Lifecycle, for: Any do
  def initialize(component, _opts), do: {:ok, component}
  def start(component), do: {:ok, component}
  def stop(component), do: {:ok, component}
  def restart(component), do: {:ok, component}
  def cleanup(_component), do: :ok
  def get_state(_component), do: :stopped
end
