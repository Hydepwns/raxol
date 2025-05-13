defmodule Raxol.Terminal.EmulatorBehaviour do
  @moduledoc """
  Defines the behaviour for the core Terminal Emulator.

  This contract outlines the essential functions for managing terminal state,
  processing input, and handling resizing.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.CharacterSets.CharacterSets
  alias Raxol.Terminal.ModeManager
  alias Raxol.Plugins.PluginManager
  alias Raxol.Terminal.Parser

  # Define the expected structure of the emulator state for specs
  # This should mirror the defstruct in Raxol.Terminal.Emulator
  @type t :: %{
          __struct__: module(),
          main_screen_buffer: ScreenBuffer.t(),
          alternate_screen_buffer: ScreenBuffer.t(),
          active_buffer_type: :main | :alternate,
          cursor: Manager.t(),
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
          style: TextFormatting.text_style(),
          memory_limit: non_neg_integer(),
          charset_state: CharacterSets.charset_state(),
          mode_manager: ModeManager.t(),
          plugin_manager: PluginManager.t(),
          options: map(),
          current_hyperlink_url: String.t() | nil,
          window_title: String.t() | nil,
          icon_name: String.t() | nil,
          tab_stops: MapSet.t(),
          output_buffer: String.t(),
          # Assuming atom type based on emulator.ex
          cursor_style: atom(),
          parser_state: Parser.State.t(),
          command_history: list(),
          max_command_history: non_neg_integer(),
          current_command_buffer: String.t(),
          # Include other fields from defstruct as needed for completeness
          saved_cursor: {non_neg_integer(), non_neg_integer()},
          # Replace 'any' with the actual type if known (e.g., TerminalState.t())
          state_stack: any(),
          last_col_exceeded: boolean()
        }

  @doc "Creates a new emulator with default dimensions and options."
  @callback new() :: t()

  @doc "Creates a new emulator with specified dimensions and default options."
  @callback new(width :: non_neg_integer(), height :: non_neg_integer()) :: t()

  @doc "Creates a new emulator with specified dimensions and options."
  @callback new(
              width :: non_neg_integer(),
              height :: non_neg_integer(),
              opts :: keyword()
            ) :: t()

  @doc "Creates a new emulator with specified dimensions, session ID, and client options."
  @callback new(
              width :: non_neg_integer(),
              height :: non_neg_integer(),
              session_id :: any(),
              client_options :: map()
            ) :: {:ok, t()} | {:error, any()}

  @doc "Returns the currently active screen buffer."
  @callback get_active_buffer(emulator :: t()) :: ScreenBuffer.t()

  @doc "Updates the currently active screen buffer in the emulator state."
  @callback update_active_buffer(
              emulator :: t(),
              new_buffer :: ScreenBuffer.t()
            ) :: t()

  @doc "Processes input data (e.g., user typing, escape sequences)."
  # Assuming {new_emulator, output}
  @callback process_input(emulator :: t(), input :: String.t()) ::
              {t(), String.t()}

  @doc "Resizes the emulator's screen buffers."
  @callback resize(
              emulator :: t(),
              new_width :: non_neg_integer(),
              new_height :: non_neg_integer()
            ) :: t()

  @doc "Gets the current cursor position (0-based)."
  @callback get_cursor_position(emulator :: t()) ::
              {non_neg_integer(), non_neg_integer()}

  @doc "Gets the current cursor visibility state."
  @callback get_cursor_visible(emulator :: t()) :: boolean()
end
