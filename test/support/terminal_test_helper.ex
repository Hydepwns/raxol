defmodule Raxol.Terminal.TestHelper do
  alias Raxol.Test.SharedUtilities

  @moduledoc """
  Test helper functions for Raxol.Terminal tests.

  This module provides test utilities for the terminal subsystem.
  """

  @doc """
  Creates a test emulator instance for testing.
  """
  def create_test_emulator do
    Raxol.Terminal.Emulator.new(80, 24)
  end

  @doc """
  Creates a test emulator instance with a struct cursor instead of a PID.
  This is useful for tests that need direct access to cursor fields.
  """
  def create_test_emulator_with_struct_cursor do
    width = 80
    height = 24

    # Create a struct cursor instead of PID
    cursor = %Raxol.Terminal.Cursor.Manager{
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
      shape: {1, 1}
    }

    main_buffer = Raxol.Terminal.ScreenBuffer.new(width, height)
    alternate_buffer = Raxol.Terminal.ScreenBuffer.new(width, height)
    mode_manager = Raxol.Terminal.ModeManager.new()

    %Raxol.Terminal.Emulator{
      width: width,
      height: height,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alternate_buffer,
      mode_manager: mode_manager,
      cursor: cursor,
      # No PID for testing
      window_manager: nil,
      style: Raxol.Terminal.ANSI.TextFormatting.Core.new(),
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
      state_stack: []
    }
  end

  @doc """
  Sets up the test environment with common configuration.
  """
  def setup_test_env do
    SharedUtilities.setup_basic_test_env()

    {:ok, SharedUtilities.create_test_context()}
  end

  @doc """
  Sets up test terminal environment.
  """
  def setup_test_terminal do
    # Set up terminal-specific test configuration
    Application.put_env(:raxol, :terminal_test_mode, true)
    :ok
  end

  @doc """
  Sets up common mocks used across tests.
  """
  def setup_common_mocks do
    SharedUtilities.setup_common_mocks()
  end

  @doc """
  Returns test events for testing.
  """
  def test_events do
    [
      {:key, %{key: :enter}},
      {:mouse, %{x: 10, y: 5, button: :left}},
      {:resize, %{width: 100, height: 50}}
    ]
  end

  @doc """
  Creates a test component for testing.
  """
  def create_test_component(module, initial_state \\ %{}) do
    %{
      module: module,
      state: initial_state,
      props: %{},
      children: []
    }
  end

  @doc """
  Creates a test plugin for testing purposes.
  """
  def create_test_plugin(name, config \\ %{}) do
    %{
      name: name,
      module: String.to_atom("TestPlugin.#{name}"),
      config: config,
      enabled: true
    }
  end

  @doc """
  Creates a test plugin module for testing.
  """
  def create_test_plugin_module(name, callbacks \\ %{}) do
    SharedUtilities.create_test_plugin_module(name, callbacks)
  end

  @doc """
  Cleans up test environment for a specific environment.
  """
  def cleanup_test_env(env \\ :default)

  def cleanup_test_env(context) when is_map(context) do
    # Extract environment from context or use default
    env = Map.get(context, :env, :default)
    cleanup_test_env(env)
  end

  def cleanup_test_env(env) do
    # Clean up any test-specific configuration
    Application.delete_env(:raxol, :test_mode)
    Application.delete_env(:raxol, :database_enabled)
    Application.delete_env(:raxol, :terminal_test_mode)

    # Clean up environment-specific configuration
    case env do
      :test ->
        Application.delete_env(:raxol, :test_mode)

      :development ->
        Application.delete_env(:raxol, :dev_mode)

      :production ->
        Application.delete_env(:raxol, :prod_mode)

      _ ->
        :ok
    end

    :ok
  end
end
