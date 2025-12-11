defmodule Raxol.UI.State.Context do
  @moduledoc """
  React-style Context API for Raxol UI components.

  Context provides a way to pass data through the component tree without having to pass
  props down manually at every level. This is especially useful for data that many
  components in an application need to access (such as theme, user authentication, etc.).

  ## Usage

      # Create a context
      theme_context = Context.create_context(%{theme: :light, colors: %{}})

      # Provide context to component tree
      %{
        type: :context_provider,
        attrs: %{
          context: theme_context,
          value: %{theme: :dark, colors: %{primary: "#007acc"}}
        },
        children: [
          %{type: :themed_button, attrs: %{label: "Click me"}}
        ]
      }

      # Consume context in a component
      defmodule ThemedButton do
        use Raxol.UI.Components.Base.Component

        def render(state, context) do
          theme = Context.use_context(context, :theme_context)

          button(
            label: state.label,
            style: %{
              background: theme.colors.primary,
              theme: theme.theme
            }
          )
        end
      end
  """

  alias Raxol.UI.State.Store

  # Context definition structure
  defmodule ContextDef do
    @moduledoc """
    Definition structure for a context.

    Defines a named context with a default value and optional display name,
    tracking all providers that supply values for this context.
    """
    @enforce_keys [:name, :default_value]
    defstruct [:name, :default_value, :display_name, :providers]

    def new(name, default_value, opts \\ []) do
      %__MODULE__{
        name: name,
        default_value: default_value,
        display_name: Keyword.get(opts, :display_name, to_string(name)),
        providers: []
      }
    end
  end

  # Context provider state
  defmodule Provider do
    @moduledoc """
    Context provider that supplies values to descendant components.

    Associates a context definition with a specific value and tracks
    child components that consume this context.
    """
    defstruct [:context, :value, :children, :id]

    def new(context, value, children) do
      %__MODULE__{
        context: context,
        value: value,
        children: children,
        id: System.unique_integer([:positive, :monotonic])
      }
    end
  end

  @doc """
  Creates a new context with a default value.

  ## Examples

      iex> theme_context = Context.create_context(%{theme: :light})
      %ContextDef{name: :theme_context, default_value: %{theme: :light}}
  """
  def create_context(default_value, name \\ nil, opts \\ []) do
    context_name = name || generate_context_name()
    ContextDef.new(context_name, default_value, opts)
  end

  @doc """
  Creates a context provider component that supplies context value to its children.
  """
  def create_provider(%ContextDef{} = context_def, value, children) do
    %{
      type: :context_provider,
      attrs: %{
        context: context_def,
        value: value
      },
      children: children
    }
  end

  @doc """
  Consumes a context value from the component's render context.

  This function should be called within a component's render function to access
  the nearest context provider's value.
  """
  def use_context(render_context, context_name) do
    context_stack = Map.get(render_context, :context_stack, %{})

    case Map.get(context_stack, context_name) do
      nil ->
        # Try to find context in global context registry
        get_default_context_value(context_name)

      provider ->
        provider.value
    end
  end

  @doc """
  Processes a context provider, managing context propagation to children.
  """
  def process_context_provider(
        %{type: :context_provider, attrs: attrs, children: children},
        render_context,
        acc
      ) do
    context_def = Map.get(attrs, :context)
    value = Map.get(attrs, :value)

    case {context_def, value} do
      {context_def, value} when not is_nil(context_def) and not is_nil(value) ->
        # Create new provider
        provider = Provider.new(context_def, value, children)

        # Update context stack for children
        current_stack = Map.get(render_context, :context_stack, %{})
        new_stack = Map.put(current_stack, context_def.name, provider)
        child_context = Map.put(render_context, :context_stack, new_stack)

        # Process children with updated context
        process_children_with_context(children, child_context, acc)

      _ ->
        # No valid context, process children normally
        process_children_with_context(children, render_context, acc)
    end
  end

  @doc """
  Creates a context consumer component for more explicit context consumption.

  ## Example

      %{
        type: :context_consumer,
        attrs: %{
          context: theme_context,
          render: fn theme ->
            %{type: :text, attrs: %{content: "Current theme: \#{theme.theme}"}}
          end
        }
      }
  """
  def create_consumer(%ContextDef{} = context_def, render_fn)
      when is_function(render_fn, 1) do
    %{
      type: :context_consumer,
      attrs: %{
        context: context_def,
        render: render_fn
      }
    }
  end

  @doc """
  Processes a context consumer, calling the render function with the context value.
  """
  def process_context_consumer(
        %{type: :context_consumer, attrs: attrs},
        render_context,
        acc
      ) do
    context_def = Map.get(attrs, :context)
    render_fn = Map.get(attrs, :render)

    case {context_def, render_fn} do
      {context_def, render_fn}
      when not is_nil(context_def) and not is_nil(render_fn) ->
        context_value = use_context(render_context, context_def.name)

        case Raxol.Core.ErrorHandling.safe_call_with_logging(
               fn ->
                 rendered_element = render_fn.(context_value)
                 # Process the rendered element
                 alias Raxol.UI.Layout.Engine
                 Engine.process_element(rendered_element, render_context, acc)
               end,
               "Error in context consumer render function"
             ) do
          {:ok, result} -> result
          {:error, _} -> acc
        end

      _ ->
        acc
    end
  end

  @doc """
  Creates a higher-order component that injects context as props.

  ## Example

      themed_button = Context.with_context(Button, theme_context, fn theme, props ->
        Map.merge(props, %{theme: theme.theme, colors: theme.colors})
      end)
  """
  def with_context(component_module, %ContextDef{} = context_def, inject_fn)
      when is_function(inject_fn, 2) do
    fn props, render_context ->
      context_value = use_context(render_context, context_def.name)
      enhanced_props = inject_fn.(context_value, props)

      # Call original component with enhanced props
      component_module.render(enhanced_props, render_context)
    end
  end

  @doc """
  Combines multiple contexts into a single provider.

  ## Example

      combined_provider = Context.combine_providers([
        {theme_context, %{theme: :dark}},
        {user_context, %{user: current_user}},
        {app_context, %{version: "1.0.0"}}
      ], children)
  """
  def combine_providers(context_value_pairs, children) do
    Enum.reduce(context_value_pairs, children, fn {context_def, value}, acc ->
      [create_provider(context_def, value, acc)]
    end)
    |> List.first()
  end

  @doc """
  Updates context value and notifies subscribers.

  This is useful for contexts that need to change over time (e.g., theme switching).
  """
  def update_context_value(context_name, new_value) do
    Store.dispatch({:update_context, context_name, new_value})

    # Notify all context subscribers
    notify_context_subscribers(context_name, new_value)
  end

  @doc """
  Subscribes to context changes for reactive updates.

  ## Example

      Context.subscribe_to_context(:theme_context, fn new_theme ->
        # Re-render components that depend on theme
        Component.request_update(self(), :theme_changed)
      end)
  """
  def subscribe_to_context(context_name, callback_fn)
      when is_function(callback_fn, 1) do
    subscriber_id = System.unique_integer([:positive, :monotonic])

    Store.dispatch(
      {:add_context_subscriber, context_name, subscriber_id, callback_fn}
    )

    # Return unsubscribe function
    fn ->
      Store.dispatch({:remove_context_subscriber, context_name, subscriber_id})
    end
  end

  # Private helper functions

  defp generate_context_name do
    :"context_#{System.unique_integer([:positive, :monotonic])}"
  end

  defp get_default_context_value(context_name) do
    case Store.get_state([:contexts, context_name]) do
      nil ->
        # Context not found, return empty map
        %{}

      %ContextDef{default_value: default_value} ->
        default_value

      other ->
        other
    end
  end

  defp process_children_with_context(children, render_context, acc)
       when is_list(children) do
    alias Raxol.UI.Layout.Engine

    Enum.reduce(children, acc, fn child, child_acc ->
      case child do
        %{type: :context_provider} ->
          process_context_provider(child, render_context, child_acc)

        %{type: :context_consumer} ->
          process_context_consumer(child, render_context, child_acc)

        _ ->
          Engine.process_element(child, render_context, child_acc)
      end
    end)
  end

  defp process_children_with_context(single_child, render_context, acc) do
    process_children_with_context([single_child], render_context, acc)
  end

  defp notify_context_subscribers(context_name, new_value) do
    subscribers = Store.get_state([:context_subscribers, context_name], [])

    Enum.each(subscribers, fn {_subscriber_id, callback_fn} ->
      Raxol.Core.ErrorHandling.safe_call_with_logging(
        fn -> callback_fn.(new_value) end,
        "Error in context subscriber callback"
      )
    end)
  end

  # Common context providers

  @doc """
  Creates a theme context with common theme properties.
  """
  def create_theme_context(theme_config \\ %{}) do
    default_theme = %{
      colors: %{
        primary: "#007acc",
        secondary: "#6c757d",
        success: "#28a745",
        warning: "#ffc107",
        error: "#dc3545",
        background: "#ffffff",
        surface: "#f8f9fa",
        text: "#212529"
      },
      typography: %{
        font_family: "monospace",
        font_sizes: %{
          small: 12,
          medium: 14,
          large: 16,
          xl: 18
        },
        line_heights: %{
          tight: 1.2,
          normal: 1.5,
          loose: 1.8
        }
      },
      spacing: %{
        xs: 4,
        sm: 8,
        md: 16,
        lg: 24,
        xl: 32
      },
      breakpoints: %{
        xs: 40,
        sm: 80,
        md: 120,
        lg: 160
      },
      dark_mode: false
    }

    merged_theme = deep_merge(default_theme, theme_config)
    create_context(merged_theme, :theme_context, display_name: "Theme")
  end

  @doc """
  Creates a user context for authentication and user data.
  """
  def create_user_context(user_data \\ %{}) do
    default_user = %{
      authenticated: false,
      user: nil,
      permissions: [],
      preferences: %{}
    }

    merged_user = Map.merge(default_user, user_data)
    create_context(merged_user, :user_context, display_name: "User")
  end

  @doc """
  Creates an application context for global app state.
  """
  def create_app_context(app_config \\ %{}) do
    default_app = %{
      name: "Raxol App",
      version: "1.0.0",
      environment: :development,
      features: %{},
      settings: %{}
    }

    merged_app = Map.merge(default_app, app_config)
    create_context(merged_app, :app_context, display_name: "Application")
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _key, %{} = left_val, %{} = right_val ->
        deep_merge(left_val, right_val)

      _key, _left_val, right_val ->
        right_val
    end)
  end
end
