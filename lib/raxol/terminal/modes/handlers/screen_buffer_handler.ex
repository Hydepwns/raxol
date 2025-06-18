defmodule Raxol.Terminal.Modes.Handlers.ScreenBufferHandler do
  @moduledoc '''
  Handles screen buffer mode operations and their side effects.
  Manages alternate screen buffer switching and related functionality.
  '''

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Modes.Types.ModeTypes

  @screen_buffer_module Application.compile_env(
                          :raxol,
                          :screen_buffer_impl,
                          Raxol.Terminal.ScreenBuffer
                        )

  @doc '''
  Handles a screen buffer mode change and applies its effects to the emulator.
  '''
  @spec handle_mode_change(atom(), ModeTypes.mode_value(), Emulator.t()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def handle_mode_change(mode_name, value, emulator) do
    case find_mode_definition(mode_name) do
      %{category: :screen_buffer} = mode_def ->
        apply_mode_effects(mode_def, value, emulator)

      _ ->
        {:error, :invalid_mode}
    end
  end

  # Private Functions

  defp find_mode_definition(mode_name) do
    ModeTypes.get_all_modes()
    |> Map.values()
    |> Enum.find(&(&1.name == mode_name))
  end

  defp apply_mode_effects(mode_def, value, emulator) do
    case mode_def.name do
      :dec_alt_screen ->
        handle_simple_alt_screen(value, emulator)

      :dec_alt_screen_save ->
        handle_alt_screen_with_save(value, emulator)

      :alt_screen_buffer ->
        handle_alt_screen_with_clear(value, emulator)

      _ ->
        {:error, :unsupported_mode}
    end
  end

  defp handle_simple_alt_screen(true, emulator) do
    # Mode 47: Simple alternate screen buffer
    with {:ok, alt_buffer} <- create_or_get_alt_buffer(emulator) do
      {:ok,
       %{
         emulator
         | alternate_screen_buffer: alt_buffer,
           active_buffer_type: :alternate
       }}
    end
  end

  defp handle_simple_alt_screen(false, emulator) do
    # Switch back to main buffer
    {:ok, %{emulator | active_buffer_type: :main}}
  end

  defp handle_alt_screen_with_save(true, emulator) do
    # Mode 1047: Alt screen with save/restore
    with {:ok, alt_buffer} <- create_or_get_alt_buffer(emulator),
         {:ok, emulator_with_saved_state} <- save_terminal_state(emulator) do
      {:ok,
       %{
         emulator_with_saved_state
         | alternate_screen_buffer: alt_buffer,
           active_buffer_type: :alternate
       }}
    end
  end

  defp handle_alt_screen_with_save(false, emulator) do
    # Switch back to main buffer and restore state
    with {:ok, emulator_with_restored_state} <- restore_terminal_state(emulator) do
      {:ok, %{emulator_with_restored_state | active_buffer_type: :main}}
    end
  end

  defp handle_alt_screen_with_clear(true, emulator) do
    # Mode 1049: Alt screen with save/restore and clear
    with {:ok, alt_buffer} <- create_or_get_alt_buffer(emulator),
         {:ok, emulator_with_saved_state} <- save_terminal_state(emulator) do
      # Clear the alternate buffer
      cleared_alt_buffer =
        @screen_buffer_module.clear(
          alt_buffer,
          TextFormatting.new()
        )

      {:ok,
       %{
         emulator_with_saved_state
         | alternate_screen_buffer: cleared_alt_buffer,
           active_buffer_type: :alternate
       }}
    end
  end

  defp handle_alt_screen_with_clear(false, emulator) do
    # Switch back to main buffer, restore state, and clear alt buffer
    with {:ok, emulator_with_restored_state} <- restore_terminal_state(emulator) do
      # Clear the alternate buffer before switching away
      if alt_buf = emulator_with_restored_state.alternate_screen_buffer do
        cleared_alt_buf =
          @screen_buffer_module.clear(
            alt_buf,
            TextFormatting.new()
          )

        {:ok,
         %{
           emulator_with_restored_state
           | alternate_screen_buffer: cleared_alt_buf,
             active_buffer_type: :main
         }}
      else
        {:ok, %{emulator_with_restored_state | active_buffer_type: :main}}
      end
    end
  end

  defp create_or_get_alt_buffer(emulator) do
    if alt_buffer = emulator.alternate_screen_buffer do
      {:ok, alt_buffer}
    else
      {width, height} =
        @screen_buffer_module.get_dimensions(emulator.main_screen_buffer)

      {:ok, @screen_buffer_module.new(width, height)}
    end
  end

  defp save_terminal_state(emulator) do
    # Get the terminal state implementation
    terminal_state_module =
      Application.get_env(
        :raxol,
        :terminal_state_impl,
        Raxol.Terminal.ANSI.TerminalState
      )

    # Save the current state
    new_stack = terminal_state_module.save_state(emulator.state_stack, emulator)
    {:ok, %{emulator | state_stack: new_stack}}
  end

  defp restore_terminal_state(emulator) do
    # Get the terminal state implementation
    terminal_state_module =
      Application.get_env(
        :raxol,
        :terminal_state_impl,
        Raxol.Terminal.ANSI.TerminalState
      )

    # Restore the previous state
    {new_stack, restored_state} =
      terminal_state_module.restore_state(emulator.state_stack)

    if restored_state do
      # Apply the restored state
      emulator_with_restored_state =
        terminal_state_module.apply_restored_data(
          emulator,
          restored_state,
          [
            :cursor,
            :style,
            :charset_state,
            :mode_manager,
            :scroll_region,
            :cursor_style
          ]
        )

      {:ok, %{emulator_with_restored_state | state_stack: new_stack}}
    else
      {:ok, emulator}
    end
  end
end
