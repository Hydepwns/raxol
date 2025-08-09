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
  alias Raxol.Terminal.ScreenUpdater
  alias Raxol.Terminal.NotificationManager
  alias Raxol.Terminal.MemoryManager
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

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

  defp handle_terminal_update(update, state) do
    case state.terminal do
      %EmulatorStruct{} = emulator ->
        _result =
          ScreenUpdater.update_screen(emulator, update)

        new_emulator = emulator

        # Notify runtime process if present
        if state.runtime_pid do
          send(
            state.runtime_pid,
            {:terminal_screen_updated, [update], new_emulator}
          )
        end

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

  defp handle_terminal_batch_update(updates, state) do
    case state.terminal do
      %EmulatorStruct{} = emulator ->
        _result =
          ScreenUpdater.batch_update_screen(emulator, updates)

        new_emulator = emulator

        # Notify runtime process if present
        if state.runtime_pid do
          send(
            state.runtime_pid,
            {:terminal_screen_updated, updates, new_emulator}
          )
        end

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
    if Map.has_key?(update, :width) and Map.has_key?(update, :height) do
      NotificationManager.notify_resized(
        state.runtime_pid,
        state.callback_module,
        update.width,
        update.height
      )
    end
  end

  defp handle_no_terminal_error(state, action, data) do
    if state.runtime_pid do
      send(
        state.runtime_pid,
        {:terminal_error, :no_terminal, %{action: action, update: data}}
      )
    end

    {:error, :no_terminal}
  end
end
