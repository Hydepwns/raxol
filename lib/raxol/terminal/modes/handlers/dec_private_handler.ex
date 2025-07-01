defmodule Raxol.Terminal.Modes.Handlers.DECPrivateHandler do
  @moduledoc """
  Handles DEC Private mode operations and their side effects.
  Manages the implementation of DEC private mode changes and their effects on the terminal.
  """

  require Raxol.Core.Runtime.Log

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
    dec_alt_screen_save: &__MODULE__.handle_alt_screen_save/2
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
    case get_mode_handler(mode_def.name) do
      {:ok, handler} -> handler.(value, emulator)
      :error -> {:error, :unsupported_mode}
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
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | cursor_keys_mode: value}}}
  end

  def handle_column_width_mode(value, emulator, width_mode) do
    target_width = calculate_target_width(width_mode, value)
    new_column_width_mode = calculate_column_width_mode(width_mode, value)

    emulator = resize_emulator_buffers(emulator, target_width)
    emulator = update_column_width_mode(emulator, new_column_width_mode)

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
        alternate_screen_buffer: alt_buffer
    }
  end

  defp maybe_resize_alt_buffer(nil, _), do: nil
  defp maybe_resize_alt_buffer(buffer, width), do: resize_buffer(buffer, width)

  defp update_column_width_mode(emulator, new_mode) do
    %{emulator | mode_manager: %{emulator.mode_manager | column_width_mode: new_mode}}
  end

  def handle_screen_mode(value, emulator) do
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | screen_mode_reverse: value}}}
  end

  def handle_origin_mode(value, emulator) do
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | origin_mode: value}}}
  end

  def handle_auto_wrap_mode(value, emulator) do
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | auto_wrap: value}}}
  end

  def handle_auto_repeat_mode(value, emulator) do
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | auto_repeat_mode: value}}}
  end

  def handle_interlace_mode(value, emulator) do
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | interlacing_mode: value}}}
  end

  def handle_cursor_visibility(value, emulator) do
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | cursor_visible: value}}}
  end

  def handle_focus_events(value, emulator) do
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | focus_events_enabled: value}}}
  end

  def handle_bracketed_paste(value, emulator) do
    {:ok, %{emulator | mode_manager: %{emulator.mode_manager | bracketed_paste_mode: value}}}
  end

  def handle_alt_screen_save(value, emulator) do
    IO.puts("DEBUG: DECPrivateHandler.handle_alt_screen_save called with value=#{inspect(value)}")
    result = {:ok, %{emulator | mode_manager: %{emulator.mode_manager | alternate_buffer_active: value}}}
    IO.puts("DEBUG: DECPrivateHandler.handle_alt_screen_save result: #{inspect(result)}")
    result
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
