defmodule Raxol.Terminal.Modes.Handlers.DECPrivateHandler do
  @moduledoc """
  Handles DEC Private mode operations and their side effects.
  Manages the implementation of DEC private mode changes and their effects on the terminal.
  """

  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Modes.Types.ModeTypes

  @mode_handlers %{
    decckm: &__MODULE__.handle_cursor_keys_mode/2,
    deccolm_132: &__MODULE__.handle_column_width_mode_wide/2,
    deccolm_80: &__MODULE__.handle_column_width_mode_normal/2,
    decscnm: &__MODULE__.handle_screen_mode/2,
    decom: &__MODULE__.handle_origin_mode/2,
    decawm: &__MODULE__.handle_auto_wrap_mode/2,
    decarm: &__MODULE__.handle_auto_repeat_mode/2,
    decinlm: &__MODULE__.handle_interlace_mode/2,
    dectcem: &__MODULE__.handle_cursor_visibility/2,
    focus_events: &__MODULE__.handle_focus_events/2,
    bracketed_paste: &__MODULE__.handle_bracketed_paste/2,
    dec_alt_screen_save: &__MODULE__.handle_alt_screen_save/2,
    decsc_deccara: &__MODULE__.handle_cursor_save_restore/2,
    alt_screen_buffer: &__MODULE__.handle_alt_screen_buffer/2,
    mouse_report_x10: &__MODULE__.handle_mouse_report_x10/2,
    mouse_report_cell_motion: &__MODULE__.handle_mouse_report_cell_motion/2,
    mouse_report_sgr: &__MODULE__.handle_mouse_report_sgr/2
  }

  @doc """
  Handles a DEC private mode change and applies its effects to the emulator.
  """
  @spec handle_mode_change(atom(), ModeTypes.mode_value(), Emulator.t()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def handle_mode_change(mode_name, value, emulator) do
    case find_mode_definition(mode_name) do
      %{category: :dec_private} = mode_def ->
        apply_mode_effects(mode_def, value, emulator)

      %{category: :screen_buffer} = mode_def ->
        apply_mode_effects(mode_def, value, emulator)

      %{category: :mouse} = mode_def ->
        apply_mode_effects(mode_def, value, emulator)

      _ ->
        {:error, :invalid_mode}
    end
  end

  @doc """
  Handles a DEC private mode change (alias for handle_mode_change/3 for compatibility).
  """
  @spec handle_mode(Emulator.t(), atom(), ModeTypes.mode_value()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def handle_mode(emulator, mode_name, value) do
    handle_mode_change(mode_name, value, emulator)
  end

  # Private Functions

  defp find_mode_definition(mode_name) do
    ModeTypes.get_all_modes()
    |> Map.values()
    |> Enum.find(&(&1.name == mode_name))
  end

  defp apply_mode_effects(mode_def, value, emulator) do
    require Logger

    Logger.debug(
      "DECPrivateHandler.apply_mode_effects called with mode_def.name=#{inspect(mode_def.name)}, value=#{inspect(value)}"
    )

    case get_mode_handler(mode_def.name) do
      {:ok, handler} ->
        Logger.debug(
          "DECPrivateHandler.apply_mode_effects: calling handler for #{inspect(mode_def.name)}"
        )

        result = handler.(value, emulator)

        Logger.debug(
          "DECPrivateHandler.apply_mode_effects: handler returned #{inspect(result)}"
        )

        result

      :error ->
        Logger.debug(
          "DECPrivateHandler.apply_mode_effects: no handler found for #{inspect(mode_def.name)}"
        )

        {:error, :unsupported_mode}
    end
  end

  defp get_mode_handler(mode_name) do
    Map.fetch(@mode_handlers, mode_name)
  end

  def handle_column_width_mode_wide(value, emulator) do
    handle_column_width_mode(value, emulator, :wide)
  end

  def handle_column_width_mode_normal(value, emulator) do
    handle_column_width_mode(value, emulator, :normal)
  end

  def handle_cursor_keys_mode(value, emulator) do
    cursor_mode = if value, do: :application, else: :normal

    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | cursor_keys_mode: cursor_mode}
     }}
  end

  def handle_column_width_mode(value, emulator, width_mode) do
    target_width = calculate_target_width(width_mode, value)
    new_column_mode = calculate_column_width_mode(width_mode, value)

    emulator = resize_emulator_buffers(emulator, target_width)
    emulator = update_column_width_mode(emulator, new_column_mode)

    {:ok, emulator}
  end

  defp calculate_target_width(:wide, true), do: 132
  defp calculate_target_width(:wide, false), do: 80
  defp calculate_target_width(:normal, _), do: 80

  defp calculate_column_width_mode(:wide, true), do: :wide
  defp calculate_column_width_mode(_, _), do: :normal

  defp resize_emulator_buffers(emulator, target_width) do
    main_buffer = resize_buffer(emulator.main_screen_buffer, target_width)

    alt_buffer =
      maybe_resize_alt_buffer(emulator.alternate_screen_buffer, target_width)

    %{
      emulator
      | main_screen_buffer: main_buffer,
        alternate_screen_buffer: alt_buffer,
        width: target_width
    }
  end

  defp maybe_resize_alt_buffer(nil, _), do: nil
  defp maybe_resize_alt_buffer(buffer, width), do: resize_buffer(buffer, width)

  defp update_column_width_mode(emulator, new_mode) do
    %{
      emulator
      | mode_manager: %{emulator.mode_manager | column_width_mode: new_mode}
    }
  end

  def handle_screen_mode(value, emulator) do
    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | screen_mode_reverse: value}
     }}
  end

  def handle_origin_mode(value, emulator) do
    {:ok,
     %{emulator | mode_manager: %{emulator.mode_manager | origin_mode: value}}}
  end

  def handle_auto_wrap_mode(value, emulator) do
    {:ok,
     %{emulator | mode_manager: %{emulator.mode_manager | auto_wrap: value}}}
  end

  def handle_auto_repeat_mode(value, emulator) do
    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | auto_repeat_mode: value}
     }}
  end

  def handle_interlace_mode(value, emulator) do
    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | interlacing_mode: value}
     }}
  end

  def handle_cursor_visibility(value, emulator) do
    # Update both mode manager and cursor manager
    new_mode_manager = %{emulator.mode_manager | cursor_visible: value}

    # Update cursor manager if it's a PID
    if pid?(emulator.cursor) do
      GenServer.call(emulator.cursor, {:set_visibility, value})
    end

    {:ok,
     %{
       emulator
       | mode_manager: new_mode_manager
     }}
  end

  def handle_focus_events(value, emulator) do
    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | focus_events_enabled: value}
     }}
  end

  def handle_bracketed_paste(value, emulator) do
    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | bracketed_paste_mode: value}
     }}
  end

  def handle_alt_screen_save(value, emulator) do
    require Logger

    Logger.debug(
      "DECPrivateHandler.handle_alt_screen_save called with value=#{inspect(value)}"
    )

    Logger.debug(
      "DECPrivateHandler.handle_alt_screen_save: initial mode_manager=#{inspect(emulator.mode_manager)}"
    )

    new_mode_manager = %{
      emulator.mode_manager
      | alternate_buffer_active: value,
        active_buffer_type: if(value, do: :alternate, else: :main)
    }

    Logger.debug(
      "DECPrivateHandler.handle_alt_screen_save: new_mode_manager=#{inspect(new_mode_manager)}"
    )

    # Update the active buffer type based on the mode
    new_active_buffer_type = if value, do: :alternate, else: :main

    Logger.debug(
      "DECPrivateHandler.handle_alt_screen_save: setting active_buffer_type to #{inspect(new_active_buffer_type)}"
    )

    # Reset cursor position to top-left when switching buffers
    new_emulator = %{
      emulator
      | mode_manager: new_mode_manager,
        active_buffer_type: new_active_buffer_type
    }

    # Reset cursor position to (0, 0) when switching to alternate buffer
    new_emulator =
      if value do
        # Reset cursor to top-left when enabling alternate buffer
        Raxol.Terminal.Cursor.Manager.set_position(new_emulator.cursor, {0, 0})
        new_emulator
      else
        new_emulator
      end

    Logger.debug(
      "DECPrivateHandler.handle_alt_screen_save: returning new_emulator with mode_manager=#{inspect(new_emulator.mode_manager)}, active_buffer_type=#{inspect(new_emulator.active_buffer_type)}"
    )

    {:ok, new_emulator}
  end

  def handle_mouse_report_x10(value, emulator) do
    mouse_mode = if value, do: :x10, else: :none

    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | mouse_report_mode: mouse_mode}
     }}
  end

  def handle_mouse_report_cell_motion(value, emulator) do
    mouse_mode = if value, do: :cell_motion, else: :none

    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | mouse_report_mode: mouse_mode}
     }}
  end

  def handle_mouse_report_sgr(value, emulator) do
    mouse_mode = if value, do: :sgr, else: :none

    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | mouse_report_mode: mouse_mode}
     }}
  end

  def handle_cursor_save_restore(value, emulator) do
    # Route to ScreenBufferHandler for cursor save/restore functionality
    Raxol.Terminal.Modes.Handlers.ScreenBufferHandler.handle_mode_change(
      :decsc_deccara,
      value,
      emulator
    )
  end

  def handle_alt_screen_buffer(value, emulator) do
    # Route to ScreenBufferHandler for alt screen buffer functionality
    Raxol.Terminal.Modes.Handlers.ScreenBufferHandler.handle_mode_change(
      :alt_screen_buffer,
      value,
      emulator
    )
  end

  defp resize_buffer(buffer, new_width) do
    # Get the configured screen buffer module
    screen_buffer_impl =
      Application.get_env(
        :raxol,
        :screen_buffer_impl,
        Raxol.Terminal.ScreenBuffer
      )

    screen_buffer_impl.resize(
      buffer,
      new_width,
      buffer.height
    )
  end
end
