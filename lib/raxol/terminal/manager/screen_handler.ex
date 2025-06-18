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
        case state.terminal do
          %EmulatorStruct{} = emulator ->
            {new_emulator, _output} =
              ScreenUpdater.update_screen(emulator, update)

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
            if state.runtime_pid do
              send(
                state.runtime_pid,
                {:terminal_error, :no_terminal,
                 %{action: :update_screen, update: update}}
              )
            end

            {:error, :no_terminal}
        end
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
        case state.terminal do
          %EmulatorStruct{} = emulator ->
            {new_emulator, _output} =
              ScreenUpdater.batch_update_screen(emulator, updates)

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
            if state.runtime_pid do
              send(
                state.runtime_pid,
                {:terminal_error, :no_terminal,
                 %{action: :batch_update_screen, updates: updates}}
              )
            end

            {:error, :no_terminal}
        end
    end
  end

  # --- Private Helpers ---

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
end
