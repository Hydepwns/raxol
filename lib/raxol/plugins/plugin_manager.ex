defmodule Raxol.Plugins.PluginManager do
  @moduledoc """
  Manages plugins for the Raxol terminal emulator.
  Handles plugin loading, lifecycle management, and event dispatching.
  """

  require Logger

  alias Raxol.Plugins.{
    Plugin,
    PluginConfig,
    PluginDependency,
    CellProcessor,
    EventHandler,
    Lifecycle
  }

  alias Raxol.Plugins.Manager.{
    Core,
    State,
    Hooks,
    Events,
    Cells
  }

  @type t :: %__MODULE__{
          plugins: %{String.t() => Plugin.t()},
          config: PluginConfig.t(),
          api_version: String.t()
        }

  defstruct [
    :plugins,
    :config,
    :api_version
  ]

  # Core functionality
  defdelegate new(config \\ %{}), to: Core
  defdelegate list_plugins(manager), to: Core
  defdelegate get_plugin(manager, name), to: Core
  defdelegate get_api_version(manager), to: Core

  # State management
  defdelegate update_plugin(manager, name, update_fun), to: State
  defdelegate enable_plugin(manager, name), to: State
  defdelegate disable_plugin(manager, name), to: State
  defdelegate load_plugin(manager, module, config \\ %{}), to: State
  defdelegate load_plugins(manager, modules), to: State
  defdelegate unload_plugin(manager, name), to: State

  # Hook execution
  defdelegate run_render_hooks(manager), to: Hooks
  defdelegate run_hook(manager, hook_name, args \\ []), to: Hooks

  # Event handling
  defdelegate process_input(manager, input), to: Events
  defdelegate process_output(manager, output), to: Events
  defdelegate process_mouse(manager, event, emulator_state), to: Events
  defdelegate handle_resize(manager, width, height), to: Events
  defdelegate handle_mouse_event(manager, event, rendered_cells), to: Events
  defdelegate broadcast_event(manager, event), to: Events

  # Cell processing
  defdelegate handle_cells(manager, cells, emulator_state), to: Cells
  defdelegate process_cell(manager, cell, emulator_state), to: Cells
  defdelegate collect_cell_commands(manager), to: Cells
end
