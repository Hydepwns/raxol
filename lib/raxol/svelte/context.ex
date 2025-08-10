defmodule Raxol.Svelte.Context do
  @moduledoc """
  Svelte-style context system for passing data through component trees
  without prop drilling.

  Similar to Svelte's setContext/getContext and React's Context API,
  but optimized for terminal applications.

  ## Example

      defmodule ThemeProvider do
        use Raxol.Svelte.Component
        use Raxol.Svelte.Context
        
        state :theme, "dark"
        
        def mount(terminal, props) do
          component = super(terminal, props)
          
          # Provide theme context to all children
          set_context(:theme, %{
            current: @theme,
            colors: get_theme_colors(@theme),
            toggle: &toggle_theme/0
          })
          
          component
        end
        
        def render(assigns) do
          ~H'''
          <Box class="theme-provider">
            {@children}
          </Box>
          '''
        end
      end
      
      defmodule ThemedButton do
        use Raxol.Svelte.Component
        use Raxol.Svelte.Context
        
        def render(assigns) do
          theme = get_context(:theme)
          
          ~H'''
          <Button 
            color={theme.colors.primary}
            background={theme.colors.background}
          >
            {@text}
          </Button>
          '''
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Raxol.Svelte.Context

      @contexts %{}
      @context_subscriptions %{}
      @before_compile Raxol.Svelte.Context
    end
  end

  @doc """
  Set a context value that child components can access.
  """
  def set_context(key, value) do
    GenServer.call(self(), {:set_context, key, value})
  end

  @doc """
  Get a context value from parent components.
  """
  def get_context(key, default \\ nil) do
    GenServer.call(self(), {:get_context, key, default})
  end

  @doc """
  Subscribe to context changes.
  """
  def subscribe_context(key, callback) when is_function(callback, 1) do
    GenServer.call(self(), {:subscribe_context, key, callback})
  end

  @doc """
  Update a context value and notify subscribers.
  """
  def update_context(key, updater) when is_function(updater, 1) do
    GenServer.call(self(), {:update_context, key, updater})
  end

  defmacro __before_compile__(_env) do
    quote do
      # Add context management to component state
      def init({terminal, props}) do
        state = %{
          terminal: terminal,
          props: props,
          state: @state_vars,
          reactive: %{},
          contexts: %{},
          context_subscriptions: %{},
          parent_component: nil,
          child_components: [],
          dirty: true,
          subscribers: []
        }

        # Calculate initial reactive values
        state = calculate_reactive(state)

        # Initial render
        send(self(), :render)

        {:ok, state}
      end

      # Handle context operations
      @impl GenServer
      def handle_call({:set_context, key, value}, _from, state) do
        contexts = Map.put(state.contexts, key, value)
        new_state = %{state | contexts: contexts}

        # Notify child components of context change
        notify_context_change(key, value, state.child_components)

        {:reply, :ok, new_state}
      end

      @impl GenServer
      def handle_call({:get_context, key, default}, _from, state) do
        value = find_context_value(key, state, default)
        {:reply, value, state}
      end

      @impl GenServer
      def handle_call({:subscribe_context, key, callback}, _from, state) do
        subscription_id = make_ref()

        subscriptions =
          state.context_subscriptions
          |> Map.update(key, [{subscription_id, callback}], fn subs ->
            [{subscription_id, callback} | subs]
          end)

        new_state = %{state | context_subscriptions: subscriptions}

        # Immediately call with current value
        current_value = find_context_value(key, state, nil)

        if current_value != nil do
          Task.start(fn -> callback.(current_value) end)
        end

        {:reply, subscription_id, new_state}
      end

      @impl GenServer
      def handle_call({:update_context, key, updater}, _from, state) do
        current_value = Map.get(state.contexts, key)
        new_value = updater.(current_value)

        contexts = Map.put(state.contexts, key, new_value)
        new_state = %{state | contexts: contexts}

        # Notify subscribers
        notify_context_change(key, new_value, state.child_components)
        notify_context_subscribers(key, new_value, state.context_subscriptions)

        {:reply, new_value, new_state}
      end

      # Component hierarchy management
      def add_child_component(parent_pid, child_pid) do
        GenServer.call(parent_pid, {:add_child, child_pid})
      end

      def remove_child_component(parent_pid, child_pid) do
        GenServer.call(parent_pid, {:remove_child, child_pid})
      end

      @impl GenServer
      def handle_call({:add_child, child_pid}, _from, state) do
        children = [child_pid | state.child_components]

        # Share current contexts with new child
        Enum.each(state.contexts, fn {key, value} ->
          GenServer.cast(child_pid, {:context_update, key, value})
        end)

        {:reply, :ok, %{state | child_components: children}}
      end

      @impl GenServer
      def handle_call({:remove_child, child_pid}, _from, state) do
        children = List.delete(state.child_components, child_pid)
        {:reply, :ok, %{state | child_components: children}}
      end

      # Handle context updates from parent
      @impl GenServer
      def handle_cast({:context_update, key, value}, state) do
        # Trigger re-render if this context is used
        if context_affects_render?(key, state) do
          send(self(), :render)
          {:noreply, %{state | dirty: true}}
        else
          {:noreply, state}
        end
      end

      # Context resolution - walk up the component tree
      defp find_context_value(key, state, default) do
        case Map.get(state.contexts, key) do
          nil ->
            # Look in parent component
            if state.parent_component do
              GenServer.call(
                state.parent_component,
                {:get_context, key, default}
              )
            else
              default
            end

          value ->
            value
        end
      end

      defp notify_context_change(key, value, child_components) do
        Enum.each(child_components, fn child_pid ->
          GenServer.cast(child_pid, {:context_update, key, value})
        end)
      end

      defp notify_context_subscribers(key, value, subscriptions) do
        subscribers = Map.get(subscriptions, key, [])

        Enum.each(subscribers, fn {_id, callback} ->
          Task.start(fn -> callback.(value) end)
        end)
      end

      defp context_affects_render?(key, state) do
        # Check if the template uses this context
        # This would need template analysis in a real implementation
        true
      end

      # Override mount to establish parent-child relationships
      def mount(terminal, props, parent)
          when is_pid(parent) or is_nil(parent) do
        {:ok, pid} = start_link(terminal, props)

        if parent do
          GenServer.call(pid, {:set_parent, parent})
          add_child_component(parent, pid)
        end

        pid
      end

      @impl GenServer
      def handle_call({:set_parent, parent_pid}, _from, state) do
        {:reply, :ok, %{state | parent_component: parent_pid}}
      end

      defoverridable mount: 2, init: 1, handle_call: 3, handle_cast: 2
    end
  end

  # Context Providers and Consumers

  @doc """
  Create a context provider component.
  """
  defmacro context_provider(name, default_value \\ nil) do
    quote do
      defmodule unquote(name) do
        use Raxol.Svelte.Component
        use Raxol.Svelte.Context

        @context_key unquote(name)
        @default_value unquote(default_value)

        def mount(terminal, props, parent)
            when is_pid(parent) or is_nil(parent) do
          {:ok, component} = GenServer.start_link(__MODULE__, {terminal, props})

          # Set the context value
          context_value = Map.get(props, :value, @default_value)
          set_context(@context_key, context_value)

          component
        end

        def render(assigns) do
          ~H"""
          {@children}
          """
        end

        def update_value(new_value) do
          update_context(@context_key, fn _current -> new_value end)
        end
      end
    end
  end

  @doc """
  Create a context consumer component.
  """
  defmacro context_consumer(context_key, do: render_block) do
    quote do
      defmodule Consumer do
        use Raxol.Svelte.Component
        use Raxol.Svelte.Context

        def render(assigns) do
          context_value = get_context(unquote(context_key))

          # Pass context value to render block
          unquote(render_block).(context_value, assigns)
        end
      end
    end
  end
end

# Built-in context providers

defmodule Raxol.Svelte.Context.ThemeProvider do
  @moduledoc """
  Built-in theme context provider.
  """
  use Raxol.Svelte.Component
  use Raxol.Svelte.Context
  use Phoenix.Component

  state(:theme, "light")

  def mount(terminal, props) do
    {:ok, component} = GenServer.start_link(__MODULE__, {terminal, props})

    theme_data = %{
      name: get_state(:theme),
      colors: get_theme_colors(get_state(:theme)),
      spacing: get_theme_spacing(get_state(:theme)),
      toggle: fn -> toggle_theme() end,
      set_theme: fn name -> set_theme(name) end
    }

    set_context(:theme, theme_data)

    component
  end

  def toggle_theme do
    current = get_state(:theme)
    new_theme = if current == "light", do: "dark", else: "light"
    set_theme(new_theme)
  end

  def set_theme(theme_name) do
    set_state(:theme, theme_name)

    # Update context
    theme_data = %{
      name: theme_name,
      colors: get_theme_colors(theme_name),
      spacing: get_theme_spacing(theme_name),
      toggle: fn -> toggle_theme() end,
      set_theme: fn name -> set_theme(name) end
    }

    update_context(:theme, fn _ -> theme_data end)
  end

  def render(assigns) do
    ~S"""
    <Box class={"theme-" <> @theme}>
      {@children}
    </Box>
    """
  end

  defp get_theme_colors("dark") do
    %{
      primary: "#3b82f6",
      secondary: "#6b7280",
      background: "#1f2937",
      surface: "#374151",
      text: "#f9fafb",
      text_secondary: "#d1d5db"
    }
  end

  defp get_theme_colors("light") do
    %{
      primary: "#2563eb",
      secondary: "#4b5563",
      background: "#ffffff",
      surface: "#f9fafb",
      text: "#111827",
      text_secondary: "#6b7280"
    }
  end

  defp get_theme_spacing(_theme) do
    %{
      xs: 1,
      sm: 2,
      md: 4,
      lg: 6,
      xl: 8
    }
  end
end

defmodule Raxol.Svelte.Context.AuthProvider do
  @moduledoc """
  Built-in authentication context provider.
  """
  use Raxol.Svelte.Component
  use Raxol.Svelte.Context
  use Phoenix.Component

  state(:user, nil)
  state(:loading, false)
  state(:error, nil)

  def mount(terminal, props, parent) when is_pid(parent) or is_nil(parent) do
    {:ok, component} = GenServer.start_link(__MODULE__, {terminal, props})

    auth_data = %{
      user: get_state(:user),
      loading: get_state(:loading),
      error: get_state(:error),
      login: fn credentials -> login(credentials) end,
      logout: fn -> logout() end,
      is_authenticated: fn -> get_state(:user) != nil end
    }

    set_context(:auth, auth_data)

    component
  end

  def login(credentials) do
    set_state(:loading, true)
    set_state(:error, nil)

    # Simulate async login
    Task.start(fn ->
      case authenticate(credentials) do
        {:ok, user} ->
          set_state(:user, user)
          set_state(:loading, false)
          update_auth_context()

        {:error, reason} ->
          set_state(:error, reason)
          set_state(:loading, false)
          update_auth_context()
      end
    end)
  end

  def logout do
    set_state(:user, nil)
    set_state(:error, nil)
    update_auth_context()
  end

  defp update_auth_context do
    auth_data = %{
      user: get_state(:user),
      loading: get_state(:loading),
      error: get_state(:error),
      login: fn credentials -> login(credentials) end,
      logout: fn -> logout() end,
      is_authenticated: fn -> get_state(:user) != nil end
    }

    update_context(:auth, fn _ -> auth_data end)
  end

  defp authenticate(_credentials) do
    # Mock authentication
    Process.sleep(1000)
    {:ok, %{id: 1, name: "User", email: "user@example.com"}}
  end

  def render(assigns) do
    ~S"""
    {@children}
    """
  end
end
