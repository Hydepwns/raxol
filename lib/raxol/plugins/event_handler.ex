defmodule Raxol.Plugins.EventHandler do
  @moduledoc """
  Handles dispatching various events (input, resize, mouse, etc.) to plugins.

  This module has been refactored to delegate specific event types to specialized modules
  for better organization and maintainability.
  """

  alias Raxol.Plugins.Manager.Core
  alias Raxol.Plugins.EventHandler.{InputEvents, OutputEvents, MouseEvents}

  @type event :: map()
  @type manager :: Core.t()
  @type result :: {:ok, manager()} | {:error, term()}

  @doc """
  Dispatches an "input" event to all enabled plugins implementing `handle_input/2`.
  """
  @spec handle_input(Core.t(), binary()) :: result()
  defdelegate handle_input(manager, input), to: InputEvents

  @doc """
  Dispatches a "key_event" to all enabled plugins implementing `handle_key_event/2`.
  """
  @spec handle_key_event(Core.t(), map()) :: result()
  defdelegate handle_key_event(manager, key_event), to: InputEvents

  @doc """
  Dispatches an "output" event to all enabled plugins implementing `handle_output/2`.
  """
  @spec handle_output(Core.t(), binary()) :: result()
  defdelegate handle_output(manager, output), to: OutputEvents

  @doc """
  Dispatches a "mouse_event" to all enabled plugins implementing `handle_mouse_event/3`.
  """
  @spec handle_mouse_event(Core.t(), map(), map()) :: result()
  defdelegate handle_mouse_event(manager, event, rendered_cells),
    to: MouseEvents

  @doc """
  Dispatches a "resize" event to all enabled plugins implementing `handle_resize/3`.
  """
  @spec handle_resize(Core.t(), non_neg_integer(), non_neg_integer()) ::
          result()
  defdelegate handle_resize(manager, width, height), to: MouseEvents

  # Legacy compatibility - these functions might be called by existing code

  @doc """
  Generic event dispatch function (legacy compatibility).
  """
  @spec dispatch_event(manager(), atom(), list(), map()) :: result()
  def dispatch_event(manager, event_type, args, _opts \\ %{}) do
    case event_type do
      :input when length(args) >= 1 ->
        handle_input(manager, hd(args))

      :output when length(args) >= 1 ->
        handle_output(manager, hd(args))

      :key_event when length(args) >= 1 ->
        handle_key_event(manager, hd(args))

      :mouse_event when length(args) >= 2 ->
        [event, rendered_cells] = args
        handle_mouse_event(manager, event, rendered_cells)

      :resize when length(args) >= 2 ->
        [width, height] = args
        handle_resize(manager, width, height)

      _ ->
        {:error, {:unsupported_event_type, event_type}}
    end
  end
end
