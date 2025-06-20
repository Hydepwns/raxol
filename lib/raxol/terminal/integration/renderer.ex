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
  # state is not used in the body with tb_clear
  def clear_screen(%State{} = _state) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just return success
      :ok
    else
      case :termbox2_nif.tb_clear() do
        0 ->
          # Also present immediately as per previous logic
          case :termbox2_nif.tb_present() do
            0 ->
              :ok

            present_error_code ->
              {:error, {:present_after_clear_failed, present_error_code}}
          end

        clear_error_code ->
          {:error, {:clear_failed, clear_error_code}}
      end
    end
  end

  @doc """
  Moves the hardware cursor to a specific position on the screen.
  Call present/0 afterwards if you want to ensure it's shown with other changes.
  The cursor position is typically updated with present/0.
  Returns :ok or {:error, reason}.
  """
  # state is not used in the body
  def move_cursor(%State{} = _state, x, y) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just return success
      :ok
    else
      case :termbox2_nif.tb_set_cursor(x, y) do
        0 ->
          # Also present immediately as per previous logic
          case :termbox2_nif.tb_present() do
            0 ->
              :ok

            present_error_code ->
              {:error, {:present_after_move_cursor_failed, present_error_code}}
          end

        set_cursor_error_code ->
          {:error, {:set_cursor_failed, set_cursor_error_code}}
      end
    end
  end

  @doc """
  Creates a new renderer with the given options.
  """
  def new(_opts \\ []) do
    {:ok, %State{}}
  end

  @doc """
  Updates the renderer configuration.
  """
  def update_config(state, _config) do
    # TODO:Implementation details...
    state
  end

  @doc """
  Sets a specific configuration value.
  """
  def set_config_value(state, _key, _value) do
    # Implementation details...
    state
  end

  @doc """
  Resets the renderer configuration to defaults.
  """
  def reset_config(state) do
    # Implementation details...
    state
  end

  @doc """
  Resizes the renderer to the given dimensions.
  """
  def resize(state, _width, _height) do
    # Implementation details...
    state
  end

  @doc """
  Sets the cursor visibility.
  """
  def set_cursor_visibility(state, _visible) do
    # Implementation details...
    state
  end

  @doc """
  Sets the terminal title.
  """
  def set_title(state, _title) do
    # Implementation details...
    state
  end

  @doc """
  Gets the terminal title.
  """
  def get_title(_state) do
    # Implementation details...
    ""
  end
end
