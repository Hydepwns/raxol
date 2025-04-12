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
          api_version: String.t()
        }

  defstruct [
    :name,
    :version,
    :description,
    :enabled,
    :config,
    :dependencies,
    :api_version
  ]

  @callback init(config :: map()) :: {:ok, term()} | {:error, String.t()}
  @callback handle_input(plugin_state :: term(), input :: String.t()) ::
              {:ok, term()} | {:error, String.t()}
  @callback handle_output(plugin_state :: term(), output :: String.t()) ::
              {:ok, term()} | {:error, String.t()}
  @callback handle_mouse(plugin_state :: term(), event :: tuple(), emulator_state :: map()) ::
              {:ok, struct()} | {:error, reason :: term()}
  @callback handle_resize(plugin_state :: term(), width :: non_neg_integer(), height :: non_neg_integer()) ::
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
  @callback handle_render(plugin_state :: struct()) :: {:ok, struct(), binary() | nil} | {:ok, struct()} | binary() | :ok

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
  (Optional) Processes the list of rendered cells before drawing.

  Allows plugins to modify the cells that will be drawn to the screen or
  to generate commands (like escape sequences) to be executed before drawing
  the final buffer.

  ## Parameters

  - `state` - The current plugin state.
  - `cells` - A list of cell tuples, typically `{x, y, char_codepoint, fg_attr, bg_attr}`
              or special marker tuples like `{:placeholder, type}`.

  ## Returns

  A tuple `{updated_cells, commands}` where:
  - `updated_cells` is the potentially modified list of cells.
  - `commands` is a list of binaries (e.g., escape sequences) to be written
    to the terminal before the buffer is presented.

  **DEPRECATED:** The return format `{updated_cells, commands}` is deprecated.

  Plugins should now return a tuple `{updated_plugin_state, updated_cells, commands}`:
  - `updated_plugin_state` is the plugin's state after processing the cells.
  - `updated_cells` is the potentially modified list of cells.
  - `commands` is a list of binaries (e.g., escape sequences) to be written
    to the terminal before the buffer is presented.
  """
  @callback handle_cells(plugin_state :: t(), cells :: list()) ::
              {updated_plugin_state :: t(), updated_cells :: list(), commands :: [binary()]}

  @optional_callbacks handle_input: 2,
                       handle_output: 2,
                       handle_mouse: 3,
                       handle_resize: 3,
                       handle_render: 1,
                       cleanup: 1,
                       handle_cells: 2

  defmacro __using__(_opts) do
    quote do
      import Raxol.Plugins.Plugin, only: [
        init: 1,
        handle_input: 2,
        handle_output: 2,
        handle_mouse: 3,
        handle_resize: 3,
        cleanup: 1,
        get_dependencies: 0,
        get_api_version: 0,
        handle_render: 1,
        handle_cells: 2
      ]
    end
  end
end
