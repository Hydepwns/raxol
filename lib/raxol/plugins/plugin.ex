defmodule Raxol.Plugins.Plugin do
  @moduledoc """
  Defines the behavior for Raxol terminal emulator plugins.
  Plugins can extend the terminal's functionality by implementing this behavior.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          description: String.t(),
          enabled: boolean(),
          config: map(),
          dependencies: list(map()),
          api_version: String.t(),
          module: atom(),
          state: any()
        }

  defstruct [
    :name,
    :version,
    :description,
    :enabled,
    :config,
    :dependencies,
    :api_version,
    :module,
    :state
  ]

  @callback init(config :: map()) :: {:ok, term()} | {:error, String.t()}
  @callback handle_input(plugin_state :: term(), input :: String.t()) ::
              {:ok, term()} | {:error, String.t()}
  @callback handle_output(plugin_state :: term(), output :: String.t()) ::
              {:ok, term()} | {:error, String.t()}
  @callback handle_mouse(
              plugin_state :: term(),
              event :: tuple(),
              emulator_state :: map()
            ) ::
              {:ok, struct()} | {:error, reason :: term()}
  @callback handle_resize(
              plugin_state :: term(),
              width :: non_neg_integer(),
              height :: non_neg_integer()
            ) ::
              {:ok, struct()} | {:error, reason :: term()}
  @callback cleanup(plugin_state :: term()) :: :ok | {:error, String.t()}

  @doc """
  Optional callback executed just before the terminal buffer is presented.
  Allows plugins to inject direct output commands (e.g., escape sequences).

  Should return:
  - `{:ok, updated_plugin_state, command_to_write}` - If state changes and command is output.
  - `{:ok, updated_plugin_state}` - If state changes but no command is output.
  - `command_to_write` - If only a command is output (state unchanged).
  - `:ok` - If nothing needs to be done.
  """
  @callback handle_render(plugin_state :: struct()) ::
              {:ok, struct(), binary() | nil} | {:ok, struct()} | binary() | :ok

  @doc """
  Returns the plugin's dependencies.
  Each dependency is a map with the following keys:
  - name: The name of the plugin
  - version: The version constraint (e.g., ">= 1.0.0")
  - optional: Whether the dependency is optional (default: false)
  """
  @callback get_dependencies() :: list(map())

  @doc """
  Returns the plugin's API version.
  This is used to check compatibility with the plugin manager.
  """
  @callback get_api_version() :: String.t()

  @doc """
  (Optional) Processes a cell, potentially a placeholder, before drawing.

  Allows plugins to identify specific cells (like placeholders) and replace them
  with actual content (a list of cells) or generate commands (like escape sequences).

  ## Parameters

  - `cell` - The specific cell being processed. Can be a regular cell map
             `%{x: _, y: _, char: _, ...}` or a special map like
             `%{type: :placeholder, value: :image, bounds: ...}`.
  - `emulator_state` - The current state map of the `Runtime` GenServer.
  - `plugin_state` - The current internal state of the plugin itself.

  ## Returns

  - `{:ok, updated_plugin_state, replacement_cells, commands}`:
    The plugin handled the cell. `replacement_cells` (a list of `{x,y,map}` tuples)
    will replace the original `cell` in the render list. `commands` are executed.
    `updated_plugin_state` is stored.
  - `{:cont, updated_plugin_state}`:
    The plugin declined to handle this cell or handled it internally without replacing it.
    The original cell is kept. `updated_plugin_state` is stored.
    Allows other plugins to potentially process the same cell.
  """
  @callback handle_cells(
              cell :: map(),
              emulator_state :: map(),
              plugin_state :: t()
            ) ::
              {:ok, updated_plugin_state :: t(), replacement_cells :: list(),
               commands :: [binary()]}
              | {:cont, updated_plugin_state :: t()}

  @optional_callbacks handle_input: 2,
                      handle_output: 2,
                      handle_mouse: 3,
                      handle_resize: 3,
                      handle_render: 1,
                      cleanup: 1,
                      handle_cells: 3

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Plugins.Plugin
    end
  end
end
