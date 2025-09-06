defmodule Raxol.Svelte.Context do
  # Suppress warnings for macro-generated GenServer callbacks that are optional
  @compile {:no_warn_undefined,
            [{:handle_cast, 2}, {:code_change, 3}, {:terminate, 2}]}

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
        
        maybe_call_callback_with_value(current_value != nil, callback, current_value)

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
        handle_context_render_update(context_affects_render?(key, state), state)
      end

      # Context resolution - walk up the component tree
      defp find_context_value(key, state, default) do
        case Map.get(state.contexts, key) do
          nil ->
            # Look in parent component
            get_context_from_parent(state.parent_component, key, default)

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

      defp maybe_call_callback_with_value(true, callback, current_value) do
        Task.start(fn -> callback.(current_value) end)
      end

      defp maybe_call_callback_with_value(false, _callback, _current_value), do: :ok

      defp handle_context_render_update(true, state) do
        send(self(), :render)
        {:noreply, %{state | dirty: true}}
      end

      defp handle_context_render_update(false, state) do
        {:noreply, state}
      end

      defp get_context_from_parent(nil, _key, default), do: default

      defp get_context_from_parent(parent_component, key, default) do
        GenServer.call(
          parent_component,
          {:get_context, key, default}
        )
      end

      defp setup_parent_child_relationship(nil, _pid), do: :ok

      defp setup_parent_child_relationship(parent, pid) do
        GenServer.call(pid, {:set_parent, parent})
        add_child_component(parent, pid)
      end

      # Override mount to establish parent-child relationships
      def mount(terminal, props, parent)
          when is_pid(parent) or is_nil(parent) do
        {:ok, pid} = start_link(terminal, props)

        setup_parent_child_relationship(parent, pid)

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
  
  # Simplified implementation without unused macro functions
  use GenServer

  def start_link(initial_theme \\ "light") do
    GenServer.start_link(__MODULE__, %{theme: initial_theme})
  end

  def get_theme_data(pid) do
    GenServer.call(pid, :get_theme_data)
  end

  def toggle_theme(pid) do
    GenServer.call(pid, :toggle_theme)
  end

  def set_theme(pid, theme_name) do
    GenServer.call(pid, {:set_theme, theme_name})
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer  
  def handle_call(:get_theme_data, _from, state) do
    theme_data = %{
      name: state.theme,
      colors: get_theme_colors(state.theme),
      spacing: get_theme_spacing(state.theme)
    }
    {:reply, theme_data, state}
  end

  @impl GenServer
  def handle_call(:toggle_theme, _from, state) do
    new_theme = case state.theme do
      "light" -> "dark"
      _ -> "light"
    end
    new_state = %{state | theme: new_theme}
    {:reply, new_theme, new_state}
  end

  @impl GenServer
  def handle_call({:set_theme, theme_name}, _from, state) do
    new_state = %{state | theme: theme_name}
    {:reply, :ok, new_state}
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
  
  # Simplified implementation without unused macro functions
  use GenServer

  def start_link(initial_user \\ nil) do
    GenServer.start_link(__MODULE__, %{user: initial_user, loading: false, error: nil})
  end

  def get_auth_data(pid) do
    GenServer.call(pid, :get_auth_data)
  end

  def login(pid, credentials) do
    GenServer.call(pid, {:login, credentials})
  end

  def logout(pid) do
    GenServer.call(pid, :logout)
  end

  def is_authenticated?(pid) do
    GenServer.call(pid, :is_authenticated?)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_auth_data, _from, state) do
    auth_data = %{
      user: state.user,
      loading: state.loading,
      error: state.error,
      is_authenticated: state.user != nil
    }
    {:reply, auth_data, state}
  end

  @impl GenServer
  def handle_call({:login, credentials}, _from, state) do
    new_state = %{state | loading: true, error: nil}
    
    # Simulate async authentication
    Task.start(fn ->
      user = authenticate(credentials)
      GenServer.cast(self(), {:login_complete, user})
    end)
    
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:logout, _from, state) do
    new_state = %{state | user: nil, error: nil, loading: false}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:is_authenticated?, _from, state) do
    {:reply, state.user != nil, state}
  end

  @impl GenServer
  def handle_cast({:login_complete, user}, state) do
    new_state = %{state | user: user, loading: false}
    {:noreply, new_state}
  end

  defp authenticate(_credentials) do
    # Mock authentication
    Process.sleep(1000)
    %{id: 1, name: "User", email: "user@example.com"}
  end
end
