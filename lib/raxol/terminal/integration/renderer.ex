defmodule Raxol.Terminal.Integration.Renderer do
  @moduledoc """
  Handles terminal output rendering and display management using Termbox2.
  """

  alias Raxol.Terminal.Integration.State
  alias Raxol.Terminal.Buffer.Manager
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  require Logger

  @doc """
  Initializes the underlying terminal system.
  Must be called before other rendering functions.
  Returns :ok or {:error, reason}.
  """
  def init_terminal do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      IO.puts(
        "[Renderer] Test mode detected, skipping actual terminal initialization"
      )

      :ok
    else
      IO.puts("[Renderer] Attempting to call :termbox2_nif.tb_init()")

      try do
        raw_init_result = :termbox2_nif.tb_init()

        case raw_init_result do
          0 ->
            IO.puts("[Renderer] :termbox2_nif.tb_init() returned 0 (success)")
            :ok

          int_val when is_integer(int_val) ->
            Logger.warning(
              "Terminal integration renderer failed to initialize: #{inspect(int_val)}",
              %{error: int_val}
            )

            {:error, {:init_failed_with_code, int_val}}

          other ->
            Logger.error(
              "[Renderer] Termbox2 NIF tb_init() returned unexpected value: #{inspect(other)}"
            )

            {:error, {:init_failed_unexpected_return, other}}
        end
      catch
        kind, reason ->
          tb_stacktrace = __STACKTRACE__

          Logger.error("""
          [Renderer] Caught exception/exit during :termbox2_nif.tb_init() call.
          Kind: #{inspect(kind)}
          Reason: #{inspect(reason)}
          Stacktrace: #{inspect(tb_stacktrace)}
          """)

          {:error, {:init_failed_exception, kind, reason}}
      end
    end
  end

  @doc """
  Shuts down the underlying terminal system.
  Must be called to restore terminal state.
  Returns :ok or {:error, reason}.
  """
  def shutdown_terminal do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      IO.puts(
        "[Renderer] Test mode detected, skipping actual terminal shutdown"
      )

      :ok
    else
      IO.puts("[Renderer] Attempting to call :termbox2_nif.tb_shutdown()")

      try do
        :termbox2_nif.tb_shutdown()
        IO.puts("[Renderer] :termbox2_nif.tb_shutdown() called.")
        :ok
      catch
        kind, reason ->
          tb_stacktrace = __STACKTRACE__

          Logger.error("""
          [Renderer] Caught exception/exit during :termbox2_nif.tb_shutdown() call.
          Kind: #{inspect(kind)}
          Reason: #{inspect(reason)}
          Stacktrace: #{inspect(tb_stacktrace)}
          """)

          {:error, {:shutdown_failed_exception, kind, reason}}
      end
    end
  end

  @doc """
  Renders the current terminal state to the screen.
  Returns :ok or {:error, reason}.
  """
  def render(%State{} = state) do
    active_buffer = Manager.get_active_buffer(state.buffer_manager)

    if active_buffer && active_buffer.cells do
      case Raxol.Terminal.Integration.CellRenderer.render(active_buffer.cells) do
        :ok -> handle_cursor_and_present(state)
        error -> error
      end
    else
      :ok
    end
  end

  defp handle_cursor_and_present(state) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just return success
      :ok
    else
      {cursor_x, cursor_y} = CursorManager.get_position(state.cursor_manager)

      case :termbox2_nif.tb_set_cursor(cursor_x, cursor_y) do
        0 -> present_buffer()
        error_code -> {:error, {:set_cursor_failed, error_code}}
      end
    end
  end

  defp present_buffer do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just return success
      :ok
    else
      case :termbox2_nif.tb_present() do
        0 -> :ok
        error_code -> {:error, {:present_failed, error_code}}
      end
    end
  end

  @doc """
  Gets the current terminal dimensions.
  Returns {:ok, {width, height}} or {:error, :dimensions_unavailable}.
  Note: termbox2 width/height C functions return int, not status codes.
  A negative value might indicate an error (e.g., not initialized).
  """
  def get_dimensions do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # Return mock dimensions for tests
      {:ok, {80, 24}}
    else
      width = :termbox2_nif.tb_width()
      height = :termbox2_nif.tb_height()

      if width >= 0 and height >= 0 do
        {:ok, {width, height}}
      else
        # Assuming negative values mean error/not initialized
        {:error, {:dimensions_unavailable, width: width, height: height}}
      end
    end
  end

  @doc """
  Clears the terminal screen (specifically, the back buffer).
  Call present/0 afterwards to make it visible.
  Returns :ok or {:error, reason}.
  """
  def clear_screen(%State{} = _state) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just return success
      :ok
    else
      clear_and_present()
    end
  end

  defp clear_and_present do
    case :termbox2_nif.tb_clear() do
      0 -> present_buffer()
      clear_error_code -> {:error, {:clear_failed, clear_error_code}}
    end
  end

  @doc """
  Moves the hardware cursor to a specific position on the screen.
  Call present/0 afterwards if you want to ensure it's shown with other changes.
  The cursor position is typically updated with present/0.
  Returns :ok or {:error, reason}.
  """
  def move_cursor(%State{} = _state, x, y) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just return success
      :ok
    else
      set_cursor_and_present(x, y)
    end
  end

  defp set_cursor_and_present(x, y) do
    case :termbox2_nif.tb_set_cursor(x, y) do
      0 ->
        present_buffer()

      set_cursor_error_code ->
        {:error, {:set_cursor_failed, set_cursor_error_code}}
    end
  end

  @doc """
  Creates a new renderer with the given options.
  """
  def new(opts \\ []) do
    # Initialize terminal if not in test mode
    case init_terminal() do
      :ok ->
        # Create initial state with configuration
        config = build_initial_config(opts)

        state = %State{
          width: Map.get(config, :width, 80),
          height: Map.get(config, :height, 24),
          config: config
        }

        {:ok, state}

      error ->
        error
    end
  end

  @doc """
  Updates the renderer configuration.
  """
  def update_config(%State{} = state, config) do
    # Merge new config with existing config
    updated_config = Map.merge(state.config || %{}, config)

    # Apply configuration changes
    case apply_config_changes(updated_config) do
      :ok ->
        %{state | config: updated_config}

      {:error, reason} ->
        Logger.error(
          "Failed to apply renderer configuration: #{inspect(reason)}"
        )

        state
    end
  end

  @doc """
  Sets a specific configuration value.
  """
  def set_config_value(%State{} = state, key, value) do
    # Update the specific key in the config
    updated_config = Map.put(state.config || %{}, key, value)

    # Apply the configuration change
    case apply_config_value(key, value) do
      :ok ->
        %{state | config: updated_config}

      {:error, reason} ->
        Logger.error("Failed to set config value #{key}: #{inspect(reason)}")
        state
    end
  end

  @doc """
  Resets the renderer configuration to defaults.
  """
  def reset_config(%State{} = state) do
    # Get default configuration
    default_config = build_initial_config([])

    # Apply default configuration
    case apply_config_changes(default_config) do
      :ok ->
        %{state | config: default_config}

      {:error, reason} ->
        Logger.error(
          "Failed to reset renderer configuration: #{inspect(reason)}"
        )

        state
    end
  end

  @doc """
  Resizes the renderer to the given dimensions.
  """
  def resize(%State{} = state, width, height)
      when is_integer(width) and is_integer(height) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just update the state
      %{state | width: width, height: height}
    else
      # In real mode, we need to handle terminal resize
      # Note: Termbox2 doesn't have a direct resize function, so we update our state
      # and let the next render cycle handle the new dimensions
      case validate_dimensions(width, height) do
        :ok ->
          %{state | width: width, height: height}

        {:error, reason} ->
          Logger.error("Invalid resize dimensions: #{inspect(reason)}")
          state
      end
    end
  end

  @doc """
  Sets the cursor visibility.
  """
  def set_cursor_visibility(%State{} = state, visible)
      when is_boolean(visible) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just update the state
      %{state | config: Map.put(state.config || %{}, :cursor_visible, visible)}
    else
      # In real mode, use termbox2 to hide/show cursor
      case set_terminal_cursor_visibility(visible) do
        :ok ->
          %{
            state
            | config: Map.put(state.config || %{}, :cursor_visible, visible)
          }

        {:error, reason} ->
          Logger.error("Failed to set cursor visibility: #{inspect(reason)}")
          state
      end
    end
  end

  @doc """
  Sets the terminal title.
  """
  def set_title(%State{} = state, title) when is_binary(title) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just update the state
      %{state | config: Map.put(state.config || %{}, :title, title)}
    else
      # In real mode, use termbox2 to set the title
      case :termbox2_nif.tb_set_title(title) do
        {:ok, "set"} ->
          %{state | config: Map.put(state.config || %{}, :title, title)}

        {:error, reason} ->
          Logger.error("Failed to set terminal title: #{inspect(reason)}")
          state

        other ->
          Logger.error(
            "Unexpected response from tb_set_title: #{inspect(other)}"
          )

          state
      end
    end
  end

  @doc """
  Gets the terminal title.
  """
  def get_title(%State{} = state) do
    # Return the title from our state
    Map.get(state.config || %{}, :title, "")
  end

  # Private helper functions

  defp build_initial_config(opts) do
    %{
      width: Keyword.get(opts, :width, 80),
      height: Keyword.get(opts, :height, 24),
      cursor_visible: Keyword.get(opts, :cursor_visible, true),
      title: Keyword.get(opts, :title, "Raxol Terminal"),
      theme:
        Keyword.get(opts, :theme, %{foreground: :white, background: :black}),
      fps: Keyword.get(opts, :fps, 60),
      font_settings: Keyword.get(opts, :font_settings, %{size: 12})
    }
  end

  defp apply_config_changes(config) do
    # Apply theme changes if present
    if Map.has_key?(config, :theme) do
      case apply_theme_config(config.theme) do
        :ok -> :ok
        error -> error
      end
    else
      :ok
    end
  end

  defp apply_config_value(:cursor_visible, visible) do
    set_terminal_cursor_visibility(visible)
  end

  defp apply_config_value(:title, title) do
    case :termbox2_nif.tb_set_title(title) do
      {:ok, "set"} -> :ok
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_response, other}}
    end
  end

  defp apply_config_value(:theme, theme) do
    apply_theme_config(theme)
  end

  defp apply_config_value(_key, _value) do
    # For other config values, just return success
    :ok
  end

  defp apply_theme_config(theme) do
    # Apply theme colors to terminal
    # Note: Termbox2 doesn't have a direct theme setting function,
    # so we just validate the theme structure
    case validate_theme(theme) do
      :ok -> :ok
      error -> error
    end
  end

  defp set_terminal_cursor_visibility(visible) do
    if visible do
      # Show cursor by setting it to a valid position (will be updated during render)
      :ok
    else
      # Hide cursor by setting it to -1, -1
      case :termbox2_nif.tb_set_cursor(-1, -1) do
        :ok -> :ok
        error_code -> {:error, {:hide_cursor_failed, error_code}}
      end
    end
  end

  defp validate_dimensions(width, height) do
    cond do
      width <= 0 ->
        {:error, {:invalid_width, width}}

      height <= 0 ->
        {:error, {:invalid_height, height}}

      width > 1000 ->
        {:error, {:width_too_large, width}}

      height > 1000 ->
        {:error, {:height_too_large, height}}

      true ->
        :ok
    end
  end

  defp validate_theme(theme) when is_map(theme) do
    # Basic theme validation
    required_keys = [:foreground, :background]

    case Enum.find(required_keys, fn key -> !Map.has_key?(theme, key) end) do
      nil -> :ok
      missing_key -> {:error, {:missing_theme_key, missing_key}}
    end
  end

  defp validate_theme(_theme) do
    {:error, :invalid_theme_format}
  end
end
