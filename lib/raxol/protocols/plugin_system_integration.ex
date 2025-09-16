defmodule Raxol.Protocols.PluginSystemIntegration do
  @moduledoc """
  Integration layer for the plugin system with protocol support.

  This module extends the existing plugin system to work seamlessly with
  the new protocol-based architecture, allowing plugins to implement
  protocols for rendering, styling, event handling, and serialization.
  """

  alias Raxol.Protocols.{Renderable, Styleable, EventHandler, Serializable}

  @doc """
  Protocol-aware plugin wrapper that automatically implements protocols
  based on plugin capabilities.
  """
  defmodule ProtocolPlugin do
    defstruct [
      :id,
      :name,
      :version,
      :module,
      :config,
      :capabilities,
      :state,
      :metadata
    ]

    @type t :: %__MODULE__{
      id: atom(),
      name: String.t(),
      version: String.t(),
      module: module(),
      config: map(),
      capabilities: MapSet.t(),
      state: map(),
      metadata: map()
    }

    def new(plugin_module, opts \\ []) do
      capabilities = detect_capabilities(plugin_module)

      %__MODULE__{
        id: Keyword.get(opts, :id, plugin_module),
        name: Keyword.get(opts, :name, to_string(plugin_module)),
        version: Keyword.get(opts, :version, "1.0.0"),
        module: plugin_module,
        config: Keyword.get(opts, :config, %{}),
        capabilities: capabilities,
        state: %{},
        metadata: Keyword.get(opts, :metadata, %{})
      }
    end

    defp detect_capabilities(module) do
      base_capabilities = MapSet.new()

      base_capabilities
      |> maybe_add_capability(:renderable, function_exported?(module, :render, 2))
      |> maybe_add_capability(:styleable, function_exported?(module, :apply_style, 2))
      |> maybe_add_capability(:event_handler, function_exported?(module, :handle_event, 3))
      |> maybe_add_capability(:serializable, function_exported?(module, :serialize, 2))
      |> maybe_add_capability(:configurable, function_exported?(module, :configure, 2))
      |> maybe_add_capability(:lifecycle, function_exported?(module, :start, 1))
    end

    defp maybe_add_capability(capabilities, capability, true) do
      MapSet.put(capabilities, capability)
    end

    defp maybe_add_capability(capabilities, _capability, false) do
      capabilities
    end
  end

  # Protocol implementations for ProtocolPlugin
  defimpl Renderable, for: ProtocolPlugin do
    def render(plugin, opts \\ []) do
      cond do
        MapSet.member?(plugin.capabilities, :renderable) ->
          apply(plugin.module, :render, [plugin, opts])

        function_exported?(plugin.module, :render_plugin, 2) ->
          apply(plugin.module, :render_plugin, [plugin, opts])

        true ->
          render_default_plugin(plugin, opts)
      end
    end

    def render_metadata(plugin) do
      base_metadata = %{
        plugin_id: plugin.id,
        plugin_name: plugin.name,
        version: plugin.version,
        capabilities: MapSet.to_list(plugin.capabilities),
        interactive: MapSet.member?(plugin.capabilities, :event_handler),
        configurable: MapSet.member?(plugin.capabilities, :configurable)
      }

      case function_exported?(plugin.module, :render_metadata, 1) do
        true ->
          custom_metadata = apply(plugin.module, :render_metadata, [plugin])
          Map.merge(base_metadata, custom_metadata)

        false ->
          Map.merge(base_metadata, plugin.metadata)
      end
    end

    defp render_default_plugin(plugin, opts) do
      width = Keyword.get(opts, :width, 50)

      """
      #{center_text("Plugin: #{plugin.name}", width)}
      #{String.duplicate("─", width)}
      ID: #{plugin.id}
      Version: #{plugin.version}
      Capabilities: #{plugin.capabilities |> MapSet.to_list() |> Enum.join(", ")}
      #{String.duplicate("─", width)}
      """
    end

    defp center_text(text, width) do
      padding = max(0, div(width - String.length(text), 2))
      String.duplicate(" ", padding) <> text
    end
  end

  defimpl Styleable, for: ProtocolPlugin do
    def apply_style(plugin, style) do
      case MapSet.member?(plugin.capabilities, :styleable) do
        true ->
          case apply(plugin.module, :apply_style, [plugin, style]) do
            %ProtocolPlugin{} = updated_plugin -> updated_plugin
            updated_state -> %{plugin | state: updated_state}
          end

        false ->
          # Store style in plugin state
          updated_state = Map.put(plugin.state, :style, style)
          %{plugin | state: updated_state}
      end
    end

    def get_style(plugin) do
      case MapSet.member?(plugin.capabilities, :styleable) do
        true -> apply(plugin.module, :get_style, [plugin])
        false -> Map.get(plugin.state, :style, %{})
      end
    end

    def merge_styles(plugin, new_style) do
      current_style = get_style(plugin)
      merged_style = Map.merge(current_style, new_style)
      apply_style(plugin, merged_style)
    end

    def reset_style(plugin) do
      apply_style(plugin, %{})
    end

    def to_ansi(plugin) do
      style = get_style(plugin)
      Styleable.to_ansi(%{style: style})
    end
  end

  defimpl EventHandler, for: ProtocolPlugin do
    def handle_event(plugin, event, state) do
      case MapSet.member?(plugin.capabilities, :event_handler) do
        true ->
          case apply(plugin.module, :handle_event, [plugin, event, state]) do
            {:ok, updated_plugin, new_state} -> {:ok, updated_plugin, new_state}
            {:error, reason} -> {:error, reason}
            other -> other
          end

        false ->
          {:unhandled, plugin, state}
      end
    end

    def can_handle?(plugin, event) do
      case MapSet.member?(plugin.capabilities, :event_handler) do
        true ->
          case function_exported?(plugin.module, :can_handle?, 2) do
            true -> apply(plugin.module, :can_handle?, [plugin, event])
            false -> true  # Assume it can handle if it has the capability
          end

        false ->
          false
      end
    end

    def get_event_listeners(plugin) do
      case function_exported?(plugin.module, :get_event_listeners, 1) do
        true -> apply(plugin.module, :get_event_listeners, [plugin])
        false -> []
      end
    end

    def subscribe(plugin, event_types) do
      case function_exported?(plugin.module, :subscribe, 2) do
        true ->
          case apply(plugin.module, :subscribe, [plugin, event_types]) do
            %ProtocolPlugin{} = updated_plugin -> updated_plugin
            updated_state -> %{plugin | state: updated_state}
          end

        false ->
          # Store subscriptions in plugin state
          current_subs = Map.get(plugin.state, :subscriptions, [])
          new_subs = Enum.uniq(current_subs ++ event_types)
          updated_state = Map.put(plugin.state, :subscriptions, new_subs)
          %{plugin | state: updated_state}
      end
    end

    def unsubscribe(plugin, event_types) do
      case function_exported?(plugin.module, :unsubscribe, 2) do
        true ->
          case apply(plugin.module, :unsubscribe, [plugin, event_types]) do
            %ProtocolPlugin{} = updated_plugin -> updated_plugin
            updated_state -> %{plugin | state: updated_state}
          end

        false ->
          # Remove from plugin state
          current_subs = Map.get(plugin.state, :subscriptions, [])
          new_subs = current_subs -- event_types
          updated_state = Map.put(plugin.state, :subscriptions, new_subs)
          %{plugin | state: updated_state}
      end
    end
  end

  defimpl Serializable, for: ProtocolPlugin do
    def serialize(plugin, format) do
      case MapSet.member?(plugin.capabilities, :serializable) do
        true ->
          apply(plugin.module, :serialize, [plugin, format])

        false ->
          serialize_default(plugin, format)
      end
    end

    def serializable?(plugin, format) do
      case MapSet.member?(plugin.capabilities, :serializable) do
        true ->
          case function_exported?(plugin.module, :serializable?, 2) do
            true -> apply(plugin.module, :serializable?, [plugin, format])
            false -> format in [:json, :binary]
          end

        false ->
          format in [:json, :binary]
      end
    end

    defp serialize_default(plugin, :json) do
      data = %{
        id: plugin.id,
        name: plugin.name,
        version: plugin.version,
        module: to_string(plugin.module),
        config: plugin.config,
        capabilities: MapSet.to_list(plugin.capabilities),
        state: plugin.state,
        metadata: plugin.metadata
      }

      case Jason.encode(data) do
        {:ok, json} -> json
        {:error, reason} -> {:error, reason}
      end
    end

    defp serialize_default(plugin, :binary) do
      # Remove function references and complex data before serialization
      serializable_plugin = %{
        plugin |
        module: to_string(plugin.module),
        capabilities: MapSet.to_list(plugin.capabilities)
      }

      :erlang.term_to_binary(serializable_plugin)
    end

    defp serialize_default(_plugin, format) do
      {:error, {:unsupported_format, format}}
    end
  end

  @doc """
  Plugin registry that maintains protocol-aware plugins.
  """
  defmodule PluginRegistry do
    use GenServer

    defstruct plugins: %{}, capabilities_index: %{}

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, %__MODULE__{}, opts)
    end

    def register_plugin(registry, plugin_module, opts \\ []) do
      plugin = ProtocolPlugin.new(plugin_module, opts)
      GenServer.call(registry, {:register, plugin})
    end

    def unregister_plugin(registry, plugin_id) do
      GenServer.call(registry, {:unregister, plugin_id})
    end

    def get_plugin(registry, plugin_id) do
      GenServer.call(registry, {:get, plugin_id})
    end

    def list_plugins(registry) do
      GenServer.call(registry, :list)
    end

    def find_plugins_by_capability(registry, capability) do
      GenServer.call(registry, {:find_by_capability, capability})
    end

    def dispatch_event_to_plugins(registry, event) do
      GenServer.call(registry, {:dispatch_event, event})
    end

    # GenServer callbacks
    @impl true
    def init(state) do
      {:ok, state}
    end

    @impl true
    def handle_call({:register, plugin}, _from, state) do
      updated_plugins = Map.put(state.plugins, plugin.id, plugin)

      updated_capabilities = Enum.reduce(plugin.capabilities, state.capabilities_index, fn cap, acc ->
        current_plugins = Map.get(acc, cap, MapSet.new())
        Map.put(acc, cap, MapSet.put(current_plugins, plugin.id))
      end)

      new_state = %{state | plugins: updated_plugins, capabilities_index: updated_capabilities}
      {:reply, {:ok, plugin.id}, new_state}
    end

    @impl true
    def handle_call({:unregister, plugin_id}, _from, state) do
      case Map.get(state.plugins, plugin_id) do
        nil ->
          {:reply, {:error, :not_found}, state}

        plugin ->
          updated_plugins = Map.delete(state.plugins, plugin_id)

          updated_capabilities = Enum.reduce(plugin.capabilities, state.capabilities_index, fn cap, acc ->
            current_plugins = Map.get(acc, cap, MapSet.new())
            updated_set = MapSet.delete(current_plugins, plugin_id)

            case MapSet.size(updated_set) do
              0 -> Map.delete(acc, cap)
              _ -> Map.put(acc, cap, updated_set)
            end
          end)

          new_state = %{state | plugins: updated_plugins, capabilities_index: updated_capabilities}
          {:reply, :ok, new_state}
      end
    end

    @impl true
    def handle_call({:get, plugin_id}, _from, state) do
      plugin = Map.get(state.plugins, plugin_id)
      {:reply, plugin, state}
    end

    @impl true
    def handle_call(:list, _from, state) do
      plugins = Map.values(state.plugins)
      {:reply, plugins, state}
    end

    @impl true
    def handle_call({:find_by_capability, capability}, _from, state) do
      plugin_ids = Map.get(state.capabilities_index, capability, MapSet.new())

      plugins = plugin_ids
      |> Enum.map(&Map.get(state.plugins, &1))
      |> Enum.filter(&(&1 != nil))

      {:reply, plugins, state}
    end

    @impl true
    def handle_call({:dispatch_event, event}, _from, state) do
      results = state.plugins
      |> Map.values()
      |> Enum.filter(&EventHandler.can_handle?(&1, event))
      |> Enum.map(fn plugin ->
        case EventHandler.handle_event(plugin, event, %{}) do
          {:ok, updated_plugin, result} ->
            # Update plugin in registry
            updated_plugins = Map.put(state.plugins, plugin.id, updated_plugin)
            state = %{state | plugins: updated_plugins}
            {:ok, plugin.id, result}

          other ->
            {plugin.id, other}
        end
      end)

      {:reply, results, state}
    end
  end

  @doc """
  Utility functions for working with protocol-aware plugins.
  """

  def load_plugin_from_config(config) when is_map(config) do
    module_name = Map.fetch!(config, "module")
    module = String.to_existing_atom("Elixir.#{module_name}")

    opts = [
      id: Map.get(config, "id", module),
      name: Map.get(config, "name", module_name),
      version: Map.get(config, "version", "1.0.0"),
      config: Map.get(config, "config", %{}),
      metadata: Map.get(config, "metadata", %{})
    ]

    ProtocolPlugin.new(module, opts)
  end

  def plugin_supports_protocol?(plugin, protocol) do
    capability = protocol_to_capability(protocol)
    MapSet.member?(plugin.capabilities, capability)
  end

  defp protocol_to_capability(Renderable), do: :renderable
  defp protocol_to_capability(Styleable), do: :styleable
  defp protocol_to_capability(EventHandler), do: :event_handler
  defp protocol_to_capability(Serializable), do: :serializable
  defp protocol_to_capability(_), do: :unknown
end