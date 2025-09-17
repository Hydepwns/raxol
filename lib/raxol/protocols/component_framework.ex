defmodule Raxol.Protocols.ComponentFramework do
  @moduledoc """
  Protocol-based component framework for Raxol.

  This module provides a modern, protocol-driven approach to building
  UI components that can be rendered, styled, and handle events in a
  unified way.

  ## Key Features

  - Protocol-based composition for maximum flexibility
  - Automatic protocol implementation injection
  - Theme and style management integration
  - Event handling with bubbling and propagation
  - Performance optimizations through protocol dispatch

  ## Usage

  ```elixir
  defmodule MyComponent do
    use Raxol.Protocols.ComponentFramework

    defcomponent :my_widget do
      @props [:title, :content, :style]
      @events [:click, :change]
      @themeable true

      def render(component, opts) do
        # Component rendering logic
      end
    end
  end
  ```
  """

  alias Raxol.Protocols.{Renderable, Styleable, EventHandler, Serializable}

  @doc """
  Macro for defining protocol-aware components.
  """
  defmacro __using__(opts \\ []) do
    quote do
      import Raxol.Protocols.ComponentFramework
      import Raxol.Protocols.ComponentFramework.DSL

      @component_opts unquote(opts)
      @before_compile Raxol.Protocols.ComponentFramework
    end
  end

  @doc """
  Macro executed before compilation to inject protocol implementations.
  """
  defmacro __before_compile__(_env) do
    quote do
      def create_component(type, props \\ %{}, opts \\ []) do
        %ComponentInstance{
          type: type,
          module: __MODULE__,
          props: props,
          state: %{},
          style: %{},
          theme: nil,
          event_handlers: %{},
          children: [],
          metadata: Map.new(opts)
        }
      end
    end
  end

  # Core component structure
  defmodule ComponentInstance do
    @moduledoc """
    Represents an instance of a protocol-aware component.
    """

    defstruct [
      # Component type (atom)
      :type,
      # Module that defines the component
      :module,
      # Component properties
      :props,
      # Component state
      :state,
      # Applied styles
      :style,
      # Applied theme
      :theme,
      # Event handler mappings
      :event_handlers,
      # Child components
      :children,
      # Additional metadata
      :metadata
    ]

    @type t :: %__MODULE__{
            type: atom(),
            module: module(),
            props: map(),
            state: map(),
            style: map(),
            theme: map() | nil,
            event_handlers: map(),
            children: [t()],
            metadata: map()
          }
  end

  # Protocol implementations for ComponentInstance
  defimpl Renderable, for: ComponentInstance do
    def render(component, opts \\ []) do
      case function_exported?(component.module, :render_component, 3) do
        true ->
          apply(component.module, :render_component, [
            component.type,
            component,
            opts
          ])

        false ->
          render_default_component(component, opts)
      end
    end

    def render_metadata(component) do
      base_metadata = %{
        component_type: component.type,
        module: component.module,
        interactive: has_event_handlers?(component),
        children_count: length(component.children),
        has_theme: has_theme?(component),
        has_custom_style: has_custom_style?(component)
      }

      Map.merge(base_metadata, component.metadata)
    end

    defp has_event_handlers?(%{event_handlers: handlers})
         when map_size(handlers) > 0,
         do: true

    defp has_event_handlers?(_), do: false

    defp has_theme?(%{theme: nil}), do: false
    defp has_theme?(%{theme: _}), do: true

    defp has_custom_style?(%{style: style}) when map_size(style) > 0, do: true
    defp has_custom_style?(_), do: false

    defp render_default_component(component, opts) do
      width = Keyword.get(opts, :width, 40)
      show_debug = Keyword.get(opts, :debug, false)

      content =
        build_content_sections(component, opts, width, show_debug)
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")

      apply_component_styling(content, component)
    end

    defp build_content_sections(component, opts, width, true) do
      [
        render_component_header(component, width),
        render_component_props(component),
        render_component_children(component, opts),
        render_debug_info(component)
      ]
    end

    defp build_content_sections(component, opts, width, false) do
      [
        render_component_header(component, width),
        render_component_props(component),
        render_component_children(component, opts)
      ]
    end

    defp render_component_header(component, width) do
      title = "#{component.type} Component"
      padding = max(0, div(width - String.length(title), 2))
      padded_title = String.duplicate(" ", padding) <> title

      border = String.duplicate("─", width)

      "#{border}\n#{padded_title}\n#{border}"
    end

    defp render_component_props(%{props: props}) when map_size(props) == 0 do
      "Props: (none)"
    end

    defp render_component_props(%{props: props}) do
      props_str =
        props
        |> Enum.map_join("\n", fn {k, v} -> "  #{k}: #{inspect(v)}" end)

      "Props:\n#{props_str}"
    end

    defp render_component_children(%{children: []}, _opts), do: ""

    defp render_component_children(%{children: children}, opts) do
      children_rendered =
        children
        |> Enum.with_index()
        |> Enum.map_join("\n\n", fn {child, index} ->
          child_content = Renderable.render(child, opts)
          "Child #{index + 1}:\n#{indent_content(child_content)}"
        end)

      "Children:\n#{children_rendered}"
    end

    defp render_debug_info(component) do
      "Debug Info:\n  State: #{inspect(component.state)}\n  Handlers: #{inspect(Map.keys(component.event_handlers))}"
    end

    defp indent_content(content) do
      content
      |> String.split("\n")
      |> Enum.map_join("\n", &("  " <> &1))
    end

    defp apply_component_styling(content, %{style: style})
         when map_size(style) == 0 do
      content
    end

    defp apply_component_styling(content, %{style: style}) do
      case Styleable.to_ansi(%{style: style}) do
        "" -> content
        ansi_codes -> "#{ansi_codes}#{content}\e[0m"
      end
    end
  end

  defimpl Styleable, for: ComponentInstance do
    def apply_style(component, style) do
      updated_style = Map.merge(component.style, style)
      %{component | style: updated_style}
    end

    def get_style(component) do
      base_style = component.theme || %{}
      Map.merge(base_style, component.style)
    end

    def merge_styles(component, new_style) do
      current_style = get_style(component)
      merged = Map.merge(current_style, new_style)
      %{component | style: merged}
    end

    def reset_style(component) do
      %{component | style: %{}}
    end

    def to_ansi(component) do
      style = get_style(component)
      Styleable.to_ansi(%{style: style})
    end
  end

  defimpl EventHandler, for: ComponentInstance do
    def handle_event(component, event, state) do
      component.event_handlers
      |> Map.get(event.type)
      |> handle_event_with_handler(component, event, state)
    end

    defp handle_event_with_handler(nil, component, event, state) do
      try_module_handler(component, event, state)
    end

    defp handle_event_with_handler(handler, component, event, state)
         when is_function(handler) do
      case handler.(component, event, state) do
        {:ok, updated_component, new_state} ->
          {:ok, updated_component, new_state}

        other ->
          other
      end
    end

    defp handle_event_with_handler(_handler_info, component, _event, state) do
      {:unhandled, component, state}
    end

    defp try_module_handler(component, event, state) do
      case function_exported?(component.module, :handle_component_event, 3) do
        true ->
          apply(component.module, :handle_component_event, [
            component,
            event,
            state
          ])

        false ->
          {:unhandled, component, state}
      end
    end

    def can_handle?(component, event) do
      Map.has_key?(component.event_handlers, event.type) or
        function_exported?(component.module, :handle_component_event, 3)
    end

    def get_event_listeners(component) do
      Map.keys(component.event_handlers)
    end

    def subscribe(component, event_types) do
      new_handlers =
        Enum.reduce(event_types, component.event_handlers, fn event_type, acc ->
          case Map.has_key?(acc, event_type) do
            true -> acc
            false -> Map.put(acc, event_type, &default_event_handler/3)
          end
        end)

      %{component | event_handlers: new_handlers}
    end

    def unsubscribe(component, event_types) do
      updated_handlers =
        Enum.reduce(event_types, component.event_handlers, fn event_type, acc ->
          Map.delete(acc, event_type)
        end)

      %{component | event_handlers: updated_handlers}
    end

    defp default_event_handler(component, event, state) do
      {:ok, component, Map.put(state, :last_event, event.type)}
    end
  end

  defimpl Serializable, for: ComponentInstance do
    def serialize(component, :json) do
      data = %{
        type: component.type,
        module: to_string(component.module),
        props: component.props,
        state: component.state,
        style: component.style,
        theme: component.theme,
        children: serialize_children(component.children),
        metadata: component.metadata
      }

      case Jason.encode(data) do
        {:ok, json} -> json
        {:error, reason} -> {:error, reason}
      end
    end

    def serialize(component, :binary) do
      # Remove function references before serialization
      serializable_component = %{
        component
        | # Remove function references
          event_handlers: %{},
          children: serialize_children_binary(component.children)
      }

      :erlang.term_to_binary(serializable_component)
    end

    def serialize(_component, format) do
      {:error, {:unsupported_format, format}}
    end

    def serializable?(_component, format) do
      format in [:json, :binary]
    end

    defp serialize_children(children) do
      Enum.map(children, fn child ->
        case Serializable.serialize(child, :json) do
          json when is_binary(json) -> Jason.decode!(json)
          {:error, _} -> %{}
        end
      end)
    end

    defp serialize_children_binary(children) do
      Enum.map(children, fn child ->
        %{child | event_handlers: %{}}
      end)
    end
  end

  # DSL for component definition
  defmodule DSL do
    @moduledoc """
    Domain-specific language for defining protocol-aware components.
    """

    defmacro defcomponent(name, do: block) do
      quote do
        def render_component(unquote(name), component, opts) do
          unquote(block)
          default_render(component, opts)
        end

        defp default_render(component, opts) do
          "Component: #{component.type}"
        end
      end
    end

    defmacro props(prop_list) when is_list(prop_list) do
      quote do
        @component_props unquote(prop_list)
      end
    end

    defmacro events(event_list) when is_list(event_list) do
      quote do
        @component_events unquote(event_list)
      end
    end

    defmacro themeable(enabled \\ true) do
      quote do
        @component_themeable unquote(enabled)
      end
    end
  end

  # Component builder utilities
  @doc """
  Create a component with the given type and properties.
  """
  def component(module, type, props \\ %{}, opts \\ []) do
    %ComponentInstance{
      type: type,
      module: module,
      props: props,
      state: %{},
      style: Keyword.get(opts, :style, %{}),
      theme: Keyword.get(opts, :theme),
      event_handlers: Keyword.get(opts, :handlers, %{}),
      children: Keyword.get(opts, :children, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Add a child component to a parent component.
  """
  def add_child(parent, child) do
    %{parent | children: parent.children ++ [child]}
  end

  @doc """
  Add multiple children to a component.
  """
  def add_children(parent, children) when is_list(children) do
    %{parent | children: parent.children ++ children}
  end

  @doc """
  Set an event handler for a component.
  """
  def on_event(component, event_type, handler) when is_function(handler) do
    updated_handlers = Map.put(component.event_handlers, event_type, handler)
    %{component | event_handlers: updated_handlers}
  end

  @doc """
  Apply a theme to a component and all its children.
  """
  def apply_theme(component, theme) do
    updated_children = Enum.map(component.children, &apply_theme(&1, theme))

    %{component | theme: theme, children: updated_children}
  end

  @doc """
  Update component state.
  """
  def set_state(component, new_state) when is_map(new_state) do
    %{component | state: Map.merge(component.state, new_state)}
  end

  @doc """
  Update component props.
  """
  def set_props(component, new_props) when is_map(new_props) do
    %{component | props: Map.merge(component.props, new_props)}
  end
end
