defmodule Raxol.Terminal.Manager.ScreenHandler do
  @moduledoc """
  Handles screen updates and batch operations.

  This module is responsible for:
  - Processing screen updates
  - Handling batch screen updates
  - Managing screen state transitions
  - Coordinating with notification system
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.MemoryManager
  alias Raxol.Terminal.NotificationManager
  alias Raxol.Terminal.ScreenUpdater

  @doc """
  Processes a single screen update and returns updated state.
  """
  @spec process_update(map(), map()) :: {:ok, map()} | {:error, term()}
  def process_update(update, state) do
    case update do
      {:memory_check, _} ->
        new_state = MemoryManager.update_usage(state)
        {:ok, new_state}

      _ ->
        handle_terminal_update(update, state)
    end
  end

  @doc """
  Processes a batch of screen updates and returns updated state.
  """
  @spec process_batch_updates([map()], map()) :: {:ok, map()} | {:error, term()}
  def process_batch_updates(updates, state) do
    case updates do
      [{:memory_check, _} | _] ->
        new_state = MemoryManager.update_usage(state)
        {:ok, new_state}

      _ ->
        handle_terminal_batch_update(updates, state)
    end
  end

  @spec handle_terminal_update(map(), map()) :: {:ok, map()} | {:error, term()}
  defp handle_terminal_update(update, state) do
    case state.terminal do
      %EmulatorStruct{} = emulator ->
        _result =
          ScreenUpdater.update_screen(
            emulator.active_buffer || emulator,
            update
          )

        new_emulator = emulator

        # Notify runtime process if present
        notify_runtime_process(state.runtime_pid, [update], new_emulator)

        # Handle resize notifications if needed
        handle_resize_notification(update, state)

        # Update state with new emulator
        new_state = %{state | terminal: new_emulator}
        updated_state = MemoryManager.check_and_cleanup(new_state)

        {:ok, updated_state}

      _ ->
        handle_no_terminal_error(state, :update_screen, update)
    end
  end

  @spec handle_terminal_batch_update([map()], map()) ::
          {:ok, map()} | {:error, term()}
  defp handle_terminal_batch_update(updates, state) do
    case state.terminal do
      %EmulatorStruct{} = emulator ->
        # Get the buffers for batch update
        buffers =
          case emulator.active_buffer do
            nil -> []
            buffer -> [buffer]
          end

        _result =
          case buffers do
            [] -> :ok
            _ -> ScreenUpdater.batch_update_screen(buffers, %{})
          end

        new_emulator = emulator

        # Notify runtime process if present
        notify_runtime_process(state.runtime_pid, updates, new_emulator)

        # Handle resize notifications for each update
        Enum.each(updates, &handle_resize_notification(&1, state))

        # Update state with new emulator
        new_state = %{state | terminal: new_emulator}
        updated_state = MemoryManager.check_and_cleanup(new_state)

        {:ok, updated_state}

      _ ->
        handle_no_terminal_error(state, :batch_update_screen, updates)
    end
  end

  defp handle_resize_notification(update, state) do
    check_and_notify_resize(update, state)
  end

  defp check_and_notify_resize(%{width: width, height: height}, state) do
    NotificationManager.notify_resized(
      state.runtime_pid,
      state.callback_module,
      width,
      height
    )
  end

  defp check_and_notify_resize(_update, _state), do: :ok

  defp handle_no_terminal_error(state, action, data) do
    send_error_if_runtime_present(state.runtime_pid, action, data)
    {:error, :no_terminal}
  end

  defp notify_runtime_process(nil, _updates, _emulator), do: :ok

  defp notify_runtime_process(runtime_pid, updates, emulator) do
    send(runtime_pid, {:terminal_screen_updated, updates, emulator})
  end

  defp send_error_if_runtime_present(nil, _action, _data), do: :ok

  defp send_error_if_runtime_present(runtime_pid, action, data) do
    send(
      runtime_pid,
      {:terminal_error, :no_terminal, %{action: action, update: data}}
    )
  end
end
