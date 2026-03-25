defmodule Raxol.Core.Accessibility.FocusManager do
  @moduledoc """
  Pure-functional helpers for focus tracking, announcements, and
  event handler registration within the AccessibilityServer state.
  """

  require Logger

  alias Raxol.Core.Accessibility.AnnouncementQueue
  alias Raxol.Core.Events.EventManager

  @doc "Returns the focus history stored in metadata."
  def get_focus_history(state) do
    Map.get(state.metadata, :focus_history, [])
  end

  @doc """
  Handles a focus change by looking up the new focus element's metadata
  and potentially enqueuing a focus announcement.

  Returns `{:noreply, new_state}`.
  """
  def handle_focus_announcement(state, new_focus) do
    metadata = Map.get(state.metadata, new_focus, %{})

    case create_focus_announcement(metadata) do
      nil ->
        {:noreply, state}

      text ->
        event_manager_pid = Process.whereis(EventManager)

        new_announcements =
          AnnouncementQueue.enqueue_focus(
            state.announcements,
            text,
            event_manager_pid
          )

        {:noreply, %{state | announcements: new_announcements}}
    end
  end

  @doc "Creates a focus announcement string from element metadata, or nil."
  def create_focus_announcement(metadata) do
    case Map.get(metadata, :label) do
      nil ->
        nil

      label ->
        explicit_role = Map.get(metadata, :role)
        description = Map.get(metadata, :description, "")

        [label, explicit_role, if(description != "", do: description)]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(", ")
    end
  end

  @doc "Registers accessibility event handlers with EventManager for the given server module."
  def register_event_handlers(server_module) do
    case Process.whereis(EventManager) do
      nil ->
        Logger.debug(
          "EventManager not available, skipping event handler registration"
        )

        :ok

      _pid ->
        EventManager.register_handler(
          :focus_change,
          server_module,
          :handle_focus_change_event
        )

        EventManager.register_handler(
          :preference_changed,
          server_module,
          :handle_preference_changed_event
        )

        EventManager.register_handler(
          :theme_changed,
          server_module,
          :handle_theme_changed_event
        )
    end
  end

  @doc "Unregisters accessibility event handlers from EventManager for the given server module."
  def unregister_event_handlers(server_module) do
    case Process.whereis(EventManager) do
      nil ->
        :ok

      _pid ->
        EventManager.unregister_handler(
          :focus_change,
          server_module,
          :handle_focus_change_event
        )

        EventManager.unregister_handler(
          :preference_changed,
          server_module,
          :handle_preference_changed_event
        )

        EventManager.unregister_handler(
          :theme_changed,
          server_module,
          :handle_theme_changed_event
        )
    end
  end
end
