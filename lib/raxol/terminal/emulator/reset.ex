defmodule Raxol.Terminal.Emulator.Reset do
  @moduledoc """
  Handles emulator reset and cleanup functions.
  This module extracts the reset logic from the main emulator.
  """

  @doc """
  Resets the terminal emulator to its initial state.
  """
  @spec reset(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def reset(emulator) do
    emulator
    |> reset_state()
    |> reset_event_handler()
    |> reset_buffer_manager()
    |> reset_config_manager()
    |> reset_command_manager()
    |> reset_window_manager()
  end

  @doc """
  Cleans up the emulator state.
  """
  @spec cleanup(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def cleanup(emulator) do
    # Stop all GenServer processes gracefully
    emulator = stop_gen_servers(emulator)

    # Clear scrollback buffers
    emulator = clear_scrollback(emulator)

    # Reset charset state to defaults
    emulator = reset_charset_state(emulator)

    # Reset style to default
    emulator = %{emulator | style: Raxol.Terminal.ANSI.TextFormatting.new()}

    # Clear output buffer
    emulator = %{emulator | output_buffer: ""}

    # Reset window state
    emulator = %{
      emulator
      | window_state: %{
          iconified: false,
          maximized: false,
          position: {0, 0},
          size: {emulator.width, emulator.height},
          size_pixels: {640, 384},
          stacking_order: :normal,
          previous_size: {emulator.width, emulator.height},
          saved_size: {emulator.width, emulator.height},
          icon_name: ""
        }
    }

    # Clear state stack
    emulator = %{emulator | state_stack: []}

    # Reset scroll region
    emulator = %{emulator | scroll_region: nil}

    # Clear saved cursor
    emulator = %{emulator | saved_cursor: nil}

    # Reset sixel state
    emulator = %{emulator | sixel_state: nil}

    # Reset last column exceeded flag
    emulator = %{emulator | last_col_exceeded: false}

    emulator
  end

  @doc """
  Stops the emulator.
  """
  @spec stop(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def stop(emulator) do
    # Perform cleanup first
    emulator = cleanup(emulator)

    # Mark emulator as stopped
    %{emulator | state: :stopped}
  end

  @doc """
  Clears the scrollback buffer.
  """
  @spec clear_scrollback(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def clear_scrollback(emulator) do
    %{emulator | scrollback_buffer: []}
  end

  @doc """
  Resets the charset state.
  """
  @spec reset_charset_state(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def reset_charset_state(emulator) do
    %{
      emulator
      | charset_state: %{
          g0: :us_ascii,
          g1: :us_ascii,
          g2: :us_ascii,
          g3: :us_ascii,
          gl: :g0,
          gr: :g0,
          single_shift: nil
        }
    }
  end

  # Private functions

  defp pid?(pid) when is_pid(pid), do: true
  defp pid?(_), do: false

  defp reset_state(emulator) do
    %{emulator | state: nil}
  end

  defp reset_event_handler(emulator) do
    %{emulator | event: nil}
  end

  defp reset_buffer_manager(emulator) do
    %{emulator | buffer: nil}
  end

  defp reset_config_manager(emulator) do
    %{emulator | config: nil}
  end

  defp reset_command_manager(emulator) do
    %{emulator | command: nil}
  end

  defp reset_window_manager(emulator) do
    %{emulator | window_manager: nil}
  end

  defp stop_gen_servers(emulator) do
    # Stop state manager
    emulator = stop_process(emulator, :state)

    # Stop event handler
    emulator = stop_process(emulator, :event)

    # Stop buffer manager
    emulator = stop_process(emulator, :buffer)

    # Stop config manager
    emulator = stop_process(emulator, :config)

    # Stop command manager
    emulator = stop_process(emulator, :command)

    # Stop cursor manager
    emulator = stop_process(emulator, :cursor)

    # Stop window manager
    emulator = stop_process(emulator, :window_manager)

    emulator
  end

  defp stop_process(emulator, field) do
    case Map.get(emulator, field) do
      pid when is_pid(pid) ->
        try do
          GenServer.stop(pid, :normal, 5000)
        catch
          :exit, _ -> :ok
        end

        %{emulator | field => nil}

      _ ->
        emulator
    end
  end
end
