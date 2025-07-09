defmodule Raxol.Terminal.TestHelper do
  @moduledoc """
  Test helper functions for Raxol.Terminal tests.

  This module delegates to Raxol.Test.Support.TestHelper to provide
  consistent test utilities across the terminal subsystem.
  """

  alias Raxol.Terminal.{ScreenBuffer, Cursor.Manager, ModeManager}

  @doc """
  Creates a test emulator instance for testing.
  """
  def create_test_emulator do
    Raxol.Test.Support.TestHelper.create_test_emulator()
  end

  @doc """
  Creates a test emulator instance with a struct cursor (not PID) for testing.
  This is useful for tests that need direct access to cursor fields.
  """
  def create_test_emulator_with_struct_cursor(opts \\ []) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)

    # Create a struct cursor instead of PID
    cursor = %Manager{
      row: 0,
      col: 0,
      visible: true,
      blinking: true,
      style: :block,
      color: nil,
      saved_row: nil,
      saved_col: nil,
      saved_style: nil,
      saved_visible: nil,
      saved_blinking: nil,
      saved_color: nil,
      top_margin: 0,
      bottom_margin: height - 1,
      blink_timer: nil,
      state: :visible,
      position: {0, 0},
      blink: true,
      custom_shape: nil,
      custom_dimensions: nil,
      blink_rate: 530,
      saved_position: nil,
      history: [],
      history_index: 0,
      history_limit: 100,
      shape: {1, 1},
      # Add additional fields that tests might expect
      attributes: %{},
      saved_attributes: %{},
      saved_blink_rate: 530,
      saved_custom_shape: nil,
      saved_custom_dimensions: nil,
      saved_shape: {1, 1}
    }

    main_buffer = ScreenBuffer.new(width, height)
    alternate_buffer = ScreenBuffer.new(width, height)
    mode_manager = ModeManager.new()

    %Raxol.Terminal.Emulator{
      width: width,
      height: height,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      mode_manager: mode_manager,
      cursor: cursor,
      # No PID for testing
      window_manager: nil,
      style: Raxol.Terminal.ANSI.TextFormatting.new(),
      scrollback_buffer: [],
      cursor_style: :block,
      charset_state: %{
        g0: :us_ascii,
        g1: :us_ascii,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g0,
        single_shift: nil
      },
      active_buffer_type: :main,
      output_buffer: "",
      scrollback_limit: 1000,
      window_title: nil,
      plugin_manager: nil,
      saved_cursor: nil,
      scroll_region: nil,
      sixel_state: nil,
      last_col_exceeded: false,
      cursor_blink_rate: 0,
      session_id: nil,
      client_options: %{},
      state_stack: [],
      # Add missing fields that tests expect
      state: :normal,
      event: nil,
      buffer: nil,
      config: nil,
      command: nil,
      window_state: %{
        iconified: false,
        maximized: false,
        position: {0, 0},
        size: {width, height},
        size_pixels: {width * 8, height * 16},
        stacking_order: :normal,
        previous_size: {width, height},
        saved_size: {width, height},
        icon_name: ""
      }
    }
  end

  # Delegate other commonly used test helper functions
  defdelegate setup_test_env(), to: Raxol.Test.Support.TestHelper
  defdelegate setup_test_terminal(), to: Raxol.Test.Support.TestHelper
  defdelegate test_events(), to: Raxol.Test.Support.TestHelper

  defdelegate create_test_component(module, initial_state \\ %{}),
    to: Raxol.Test.Support.TestHelper

  defdelegate cleanup_test_env(context), to: Raxol.Test.Support.TestHelper
  defdelegate setup_common_mocks(), to: Raxol.Test.Support.TestHelper

  defdelegate create_test_plugin(name, config \\ %{}),
    to: Raxol.Test.Support.TestHelper

  defdelegate create_test_plugin_module(name, callbacks \\ %{}),
    to: Raxol.Test.Support.TestHelper
end
