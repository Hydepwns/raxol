defmodule Raxol.Terminal.Modes.Handlers.DECPrivateHandler do
  @moduledoc """
  Handles DEC Private mode operations and their side effects.
  Manages the implementation of DEC private mode changes and their effects on the terminal.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Modes.Types.ModeTypes

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

  # Private Functions

  defp find_mode_definition(mode_name) do
    ModeTypes.get_all_modes()
    |> Map.values()
    |> Enum.find(&(&1.name == mode_name))
  end

  defp apply_mode_effects(mode_def, value, emulator) do
    case mode_def.name do
      :decckm ->
        handle_cursor_keys_mode(value, emulator)

      :deccolm_132 ->
        handle_column_width_mode(value, emulator, :wide)

      :deccolm_80 ->
        handle_column_width_mode(value, emulator, :normal)

      :decscnm ->
        handle_screen_mode(value, emulator)

      :decom ->
        handle_origin_mode(value, emulator)

      :decawm ->
        handle_auto_wrap_mode(value, emulator)

      :decarm ->
        handle_auto_repeat_mode(value, emulator)

      :decinlm ->
        handle_interlace_mode(value, emulator)

      :dectcem ->
        handle_cursor_visibility(value, emulator)

      :focus_events ->
        handle_focus_events(value, emulator)

      :bracketed_paste ->
        handle_bracketed_paste(value, emulator)

      _ ->
        {:error, :unsupported_mode}
    end
  end

  defp handle_cursor_keys_mode(value, emulator) do
    # Update cursor keys mode in emulator
    {:ok, %{emulator | cursor_keys_mode: value}}
  end

  defp handle_column_width_mode(value, emulator, width_mode) do
    if value do
      new_width = if width_mode == :wide, do: 132, else: 80

      # Resize main buffer
      main_buffer = resize_buffer(emulator.main_screen_buffer, new_width)

      # Resize alternate buffer if it exists
      alt_buffer =
        if emulator.alternate_screen_buffer do
          resize_buffer(emulator.alternate_screen_buffer, new_width)
        end

      emulator = %{
        emulator
        | main_screen_buffer: main_buffer,
          alternate_screen_buffer: alt_buffer
      }

      {:ok, emulator}
    else
      {:ok, emulator}
    end
  end

  defp handle_screen_mode(value, emulator) do
    # Update screen mode (reverse video)
    {:ok, %{emulator | screen_mode_reverse: value}}
  end

  defp handle_origin_mode(value, emulator) do
    # Update origin mode
    {:ok, %{emulator | origin_mode: value}}
  end

  defp handle_auto_wrap_mode(value, emulator) do
    # Update auto wrap mode
    {:ok, %{emulator | auto_wrap: value}}
  end

  defp handle_auto_repeat_mode(value, emulator) do
    # Update auto repeat mode
    {:ok, %{emulator | auto_repeat: value}}
  end

  defp handle_interlace_mode(value, emulator) do
    # Update interlace mode
    {:ok, %{emulator | interlacing_mode: value}}
  end

  defp handle_cursor_visibility(value, emulator) do
    # Update cursor visibility
    {:ok, %{emulator | cursor_visible: value}}
  end

  defp handle_focus_events(value, emulator) do
    # Update focus events mode
    {:ok, %{emulator | focus_events_enabled: value}}
  end

  defp handle_bracketed_paste(value, emulator) do
    # Update bracketed paste mode
    {:ok, %{emulator | bracketed_paste_mode: value}}
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
