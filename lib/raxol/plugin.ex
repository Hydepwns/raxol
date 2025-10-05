defmodule Raxol.Plugin do
  @moduledoc """
  Behavior for Raxol plugins.

  Plugins extend Raxol with custom functionality while maintaining a consistent
  interface for lifecycle management, input handling, and rendering.

  ## Example

      defmodule MyApp.HelloPlugin do
        @behaviour Raxol.Plugin

        alias Raxol.Core.Buffer

        @impl true
        def init(_opts) do
          {:ok, %{counter: 0}}
        end

        @impl true
        def handle_input(key, _modifiers, state) do
          case key do
            " " -> {:ok, %{state | counter: state.counter + 1}}
            "r" -> {:ok, %{counter: 0}}
            "q" -> {:exit, state}
            _ -> {:ok, state}
          end
        end

        @impl true
        def render(buffer, state) do
          buffer
          |> Buffer.write_at(0, 0, "Hello from plugin!", %{bold: true})
          |> Buffer.write_at(0, 1, "Counter: \#{state.counter}")
          |> Buffer.write_at(0, 2, "Press SPACE to increment, R to reset, Q to quit")
        end

        @impl true
        def cleanup(_state), do: :ok
      end

  ## Plugin State

  Plugin state is managed by the plugin itself and passed between callbacks.
  The state can be any Elixir term (map, struct, etc.).

  ## Input Handling

  The `handle_input/3` callback receives:
  - `key` - The key pressed (string or atom for special keys)
  - `modifiers` - Map with `:ctrl`, `:alt`, `:shift`, `:meta` flags
  - `state` - Current plugin state

  It should return:
  - `{:ok, new_state}` - Continue with updated state
  - `{:exit, state}` - Signal plugin should exit
  - `{:error, reason}` - Signal an error occurred

  ## Rendering

  The `render/2` callback receives a buffer and current state, and should
  return the modified buffer. All rendering is done using the Raxol.Core.Buffer
  API for consistency.

  ## Lifecycle

  1. `init/1` - Called when plugin starts
  2. `handle_input/3` - Called for each input event
  3. `render/2` - Called to render current state
  4. `cleanup/1` - Called when plugin exits

  """

  alias Raxol.Core.Buffer

  @type key :: String.t() | atom()
  @type modifiers :: %{
          ctrl: boolean(),
          alt: boolean(),
          shift: boolean(),
          meta: boolean()
        }
  @type state :: any()
  @type init_opts :: keyword() | map()

  @doc """
  Initialize the plugin with given options.

  Called once when the plugin is first loaded. Should return `{:ok, initial_state}`
  or `{:error, reason}` if initialization fails.

  ## Examples

      def init(opts) do
        api_key = Keyword.get(opts, :api_key)
        {:ok, %{api_key: api_key, data: []}}
      end

  """
  @callback init(init_opts()) :: {:ok, state()} | {:error, term()}

  @doc """
  Handle keyboard or mouse input.

  Called for each input event. Should return `{:ok, new_state}` to continue,
  `{:exit, state}` to signal plugin exit, or `{:error, reason}` on error.

  ## Special Keys

  Special keys are represented as atoms:
  - `:enter`, `:escape`, `:tab`, `:backspace`, `:delete`
  - `:up`, `:down`, `:left`, `:right`
  - `:home`, `:end`, `:page_up`, `:page_down`
  - `:f1` through `:f12`

  ## Examples

      def handle_input(key, modifiers, state) do
        cond do
          key == "q" -> {:exit, state}
          key == :enter -> {:ok, process_input(state)}
          modifiers.ctrl and key == "c" -> {:exit, state}
          true -> {:ok, state}
        end
      end

  """
  @callback handle_input(key(), modifiers(), state()) ::
              {:ok, state()} | {:exit, state()} | {:error, term()}

  @doc """
  Render the plugin's current state to a buffer.

  Called each frame to render the plugin's UI. Receives the buffer and current
  state, should return the modified buffer.

  ## Examples

      def render(buffer, state) do
        buffer
        |> Buffer.write_at(0, 0, "Status: \#{state.status}")
        |> Buffer.write_at(0, 1, "Data: \#{length(state.data)} items")
      end

  """
  @callback render(Buffer.t(), state()) :: Buffer.t()

  @doc """
  Clean up plugin resources.

  Called when the plugin is about to exit. Use this to close connections,
  save state, cancel timers, etc.

  ## Examples

      def cleanup(state) do
        if state.connection do
          Connection.close(state.connection)
        end
        :ok
      end

  """
  @callback cleanup(state()) :: :ok | {:error, term()}

  @doc """
  Optional callback for handling timer/async events.

  If your plugin needs to handle periodic updates or async messages,
  implement this callback. It receives a message and current state.

  ## Examples

      def handle_info(:tick, state) do
        {:ok, %{state | last_update: System.monotonic_time()}}
      end

      def handle_info({:api_response, data}, state) do
        {:ok, %{state | data: data}}
      end

  """
  @callback handle_info(term(), state()) ::
              {:ok, state()} | {:exit, state()} | {:error, term()}

  @optional_callbacks handle_info: 2

  @doc """
  Run a plugin with the given module and options.

  This is a convenience function for testing plugins or running them
  standalone without the full framework.

  ## Examples

      Raxol.Plugin.run(MyApp.HelloPlugin, buffer_width: 80, buffer_height: 24)

  """
  @spec run(module(), keyword()) :: :ok
  def run(plugin_module, opts \\ []) do
    width = Keyword.get(opts, :buffer_width, 80)
    height = Keyword.get(opts, :buffer_height, 24)

    case plugin_module.init(opts) do
      {:ok, state} ->
        buffer = Buffer.create_blank_buffer(width, height)
        run_loop(plugin_module, buffer, state)

      {:error, reason} ->
        IO.puts("Plugin initialization failed: #{inspect(reason)}")
        :error
    end
  end

  defp run_loop(plugin_module, buffer, state) do
    rendered_buffer = plugin_module.render(buffer, state)
    IO.puts(Buffer.to_string(rendered_buffer))
    IO.puts("\n[Press 'q' to quit]")

    case IO.gets("") do
      :eof ->
        plugin_module.cleanup(state)
        :ok

      input ->
        key = String.trim(input)
        modifiers = %{ctrl: false, alt: false, shift: false, meta: false}

        case plugin_module.handle_input(key, modifiers, state) do
          {:ok, new_state} ->
            run_loop(plugin_module, buffer, new_state)

          {:exit, final_state} ->
            plugin_module.cleanup(final_state)
            :ok

          {:error, reason} ->
            IO.puts("Plugin error: #{inspect(reason)}")
            plugin_module.cleanup(state)
            :error
        end
    end
  end
end
