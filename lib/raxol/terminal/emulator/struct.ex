defmodule Raxol.Terminal.Emulator.Struct do
  @moduledoc """
  Defines the struct and types for the Terminal Emulator.
  This module exists to break circular dependencies between the Emulator and other modules.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ModeManager
  alias Raxol.Plugins.Manager.Core

  @type cursor_style_type ::
          :blinking_block
          | :steady_block
          | :blinking_underline
          | :steady_underline
          | :blinking_bar
          | :steady_bar

  @type t :: %__MODULE__{
          main_screen_buffer: ScreenBuffer.t(),
          alternate_screen_buffer: ScreenBuffer.t(),
          active_buffer_type: :main | :alternate,
          cursor: Manager.t(),
          saved_cursor: Manager.t() | nil,
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
          style: TextFormatting.text_style(),
          memory_limit: non_neg_integer(),
          charset_state: CharacterSets.charset_state(),
          mode_manager: ModeManager.t(),
          plugin_manager: Manager.t(Core),
          options: map(),
          current_hyperlink_url: String.t() | nil,
          window_title: String.t() | nil,
          icon_name: String.t() | nil,
          tab_stops: MapSet.t(),
          output_buffer: String.t(),
          color_palette: map(),
          cursor_style: cursor_style_type(),
          parser_state: map(),
          command_history: list(),
          max_command_history: non_neg_integer(),
          current_command_buffer: String.t(),
          last_key_event: map() | nil,
          width: non_neg_integer(),
          height: non_neg_integer(),
          state: term(),
          command: term(),
          window_state: %{
            title: String.t(),
            icon_name: String.t(),
            size: {non_neg_integer(), non_neg_integer()},
            position: {non_neg_integer(), non_neg_integer()},
            stacking_order: :normal | :maximized | :iconified,
            iconified: boolean(),
            maximized: boolean(),
            previous_size: {non_neg_integer(), non_neg_integer()} | nil
          },
          scrollback_buffer: list(),
          cwd: String.t() | nil,
          current_hyperlink: map() | nil,
          default_palette: map() | nil,
          scrollback_limit: non_neg_integer(),
          session_id: String.t() | nil,
          client_options: map(),
          sixel_state: map() | nil
        }

  defstruct cursor: Manager.new(),
            saved_cursor: nil,
            style: TextFormatting.new(),
            charset_state: CharacterSets.new(),
            mode_manager: ModeManager.new(),
            tab_stops: MapSet.new(),
            main_screen_buffer: nil,
            alternate_screen_buffer: nil,
            active_buffer_type: :main,
            state_stack: TerminalState.new(),
            scroll_region: nil,
            memory_limit: 1_000_000,
            last_col_exceeded: false,
            plugin_manager: Core.new(),
            parser_state: %Raxol.Terminal.Parser.State{state: :ground},
            options: %{},
            current_hyperlink_url: nil,
            window_title: nil,
            icon_name: nil,
            output_buffer: "",
            color_palette: %{},
            cursor_style: :blinking_block,
            command_history: [],
            max_command_history: 100,
            current_command_buffer: "",
            last_key_event: nil,
            width: 80,
            height: 24,
            state: nil,
            command: nil,
            window_state: %{
              title: "",
              icon_name: "",
              size: {80, 24},
              position: {0, 0},
              stacking_order: :normal,
              iconified: false,
              maximized: false,
              previous_size: nil
            },
            scrollback_buffer: [],
            cwd: nil,
            current_hyperlink: nil,
            default_palette: nil,
            scrollback_limit: 1000,
            session_id: nil,
            client_options: %{},
            sixel_state: nil
end
