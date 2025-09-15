defmodule Raxol.Protocols.BehaviourAdapter do
  @moduledoc """
  Adapter module to help migrate from behaviours to protocols.

  This module provides adapter functions that bridge the gap between
  the old behaviour-based system and the new protocol-based system,
  allowing for gradual migration without breaking existing code.

  ## Usage

  For modules implementing behaviours, you can use this adapter to
  automatically implement the corresponding protocols:

      defmodule MyRenderer do
        @behaviour Raxol.Terminal.RendererBehaviour
        use Raxol.Protocols.BehaviourAdapter, :renderer

        # Your existing behaviour callbacks...
      end

  This will automatically implement the Renderable protocol for your module.
  """

  @doc """
  Macro to inject protocol implementations based on behaviour type.
  """
  defmacro __using__(adapter_type) do
    case adapter_type do
      :renderer ->
        quote do
          defimpl Raxol.Protocols.Renderable, for: __MODULE__ do
            def render(data, opts) do
              # Bridge to the behaviour callback
              apply(__MODULE__, :render, [data | [opts]])
            end

            def render_metadata(data) do
              # Provide default metadata or bridge to behaviour
              if function_exported?(__MODULE__, :get_metadata, 1) do
                apply(__MODULE__, :get_metadata, [data])
              else
                %{width: 80, height: 24, colors: true, scrollable: false, interactive: false}
              end
            end
          end
        end

      :buffer ->
        quote do
          defimpl Raxol.Protocols.BufferOperations, for: __MODULE__ do
            def write(buffer, {x, y}, data, style) do
              apply(__MODULE__, :write_char, [buffer, x, y, data, style])
            end

            def read(buffer, {x, y}, length) do
              apply(__MODULE__, :get_char, [buffer, x, y])
            end

            def clear(buffer, :all) do
              apply(__MODULE__, :clear_screen, [buffer])
            end

            def clear(buffer, region) do
              apply(__MODULE__, :clear, [buffer, region])
            end

            def dimensions(buffer) do
              apply(__MODULE__, :get_dimensions, [buffer])
            end

            def scroll(buffer, direction, lines) do
              case direction do
                :up -> apply(__MODULE__, :scroll_up, [buffer, lines])
                :down -> apply(__MODULE__, :scroll_down, [buffer, lines])
              end
            end
          end
        end

      _ ->
        quote do
          # No-op for unknown adapter types
        end
    end
  end

  @doc """
  Wraps a behaviour-implementing module to work with protocol-expecting code.

  ## Examples

      # Old behaviour-based renderer
      renderer = MyRenderer.new(buffer)

      # Wrap it to work with protocol-expecting code
      wrapped = BehaviourAdapter.wrap_renderer(renderer)
      Raxol.Protocols.Renderable.render(wrapped, [])
  """

  # Wrapper structs for protocol dispatch
  defmodule RendererWrapper do
    defstruct [:module]
  end

  defmodule BufferWrapper do
    defstruct [:module]
  end

  defmodule EventHandlerWrapper do
    defstruct [:module]
  end

  def wrap_renderer(renderer) do
    %RendererWrapper{module: renderer}
  end

  def wrap_buffer(buffer) do
    %BufferWrapper{module: buffer}
  end

  def wrap_event_handler(handler) do
    %EventHandlerWrapper{module: handler}
  end

  # Protocol implementations for wrappers
  defimpl Raxol.Protocols.Renderable, for: RendererWrapper do
    def render(%{module: module}, opts) do
      apply(module.__struct__, :render, [module, opts])
    end

    def render_metadata(%{module: module}) do
      if function_exported?(module.__struct__, :get_metadata, 1) do
        apply(module.__struct__, :get_metadata, [module])
      else
        %{width: 80, height: 24, colors: true, scrollable: false, interactive: false}
      end
    end
  end

  defimpl Raxol.Protocols.BufferOperations, for: BufferWrapper do
    def write(%{module: module}, {x, y}, data, style) do
      updated = apply(module.__struct__, :write_char, [module, x, y, data, style])
      %{module: updated}
    end

    def read(%{module: module}, {x, y}, length) do
      apply(module.__struct__, :get_char, [module, x, y])
    end

    def clear(%{module: module}, region) do
      updated = apply(module.__struct__, :clear, [module, region])
      %{module: updated}
    end

    def dimensions(%{module: module}) do
      apply(module.__struct__, :get_dimensions, [module])
    end

    def scroll(%{module: module}, direction, lines) do
      updated = case direction do
        :up -> apply(module.__struct__, :scroll_up, [module, lines])
        :down -> apply(module.__struct__, :scroll_down, [module, lines])
      end
      %{module: updated}
    end
  end

  defimpl Raxol.Protocols.EventHandler, for: EventHandlerWrapper do
    def handle_event(%{module: module}, event, state) do
      case apply(module.__struct__, :handle_event, [module, event, state]) do
        {:ok, updated, new_state} -> {:ok, %{module: updated}, new_state}
        other -> other
      end
    end

    def can_handle?(%{module: module}, event) do
      if function_exported?(module.__struct__, :can_handle?, 2) do
        apply(module.__struct__, :can_handle?, [module, event])
      else
        true
      end
    end

    def get_event_listeners(%{module: module}) do
      if function_exported?(module.__struct__, :get_event_listeners, 1) do
        apply(module.__struct__, :get_event_listeners, [module])
      else
        []
      end
    end

    def subscribe(%{module: module} = wrapper, event_types) do
      if function_exported?(module.__struct__, :subscribe, 2) do
        updated = apply(module.__struct__, :subscribe, [module, event_types])
        %{wrapper | module: updated}
      else
        wrapper
      end
    end

    def unsubscribe(%{module: module} = wrapper, event_types) do
      if function_exported?(module.__struct__, :unsubscribe, 2) do
        updated = apply(module.__struct__, :unsubscribe, [module, event_types])
        %{wrapper | module: updated}
      else
        wrapper
      end
    end
  end
end