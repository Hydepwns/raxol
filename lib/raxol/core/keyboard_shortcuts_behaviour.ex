defmodule Raxol.Core.KeyboardShortcutsBehaviour do
  @moduledoc """
  Behavior for KeyboardShortcuts implementation.

  This defines the expected interface for keyboard shortcuts functionality
  used by the UX refinement system.
  """

  @doc """
  Initialize the keyboard shortcuts system.
  """
  @callback init() :: :ok | {:error, term()}

  @doc """
  Set the current shortcuts context.
  """
  @callback set_context(context :: atom()) :: :ok | {:error, term()}

  @doc """
  Get available shortcuts for the current context.
  """
  @callback get_available_shortcuts() :: list(map())

  @doc """
  Get shortcuts for a specific context.
  """
  @callback get_shortcuts_for_context(context :: atom() | nil) :: term()

  @doc """
  Show shortcuts help.
  """
  @callback show_shortcuts_help(user_prefs :: term()) :: :ok | {:error, term()}

  @doc """
  Handle keyboard events.
  """
  @callback handle_keyboard_event(atom(), term()) :: :ok | {:error, term()}

  @doc """
  Clean up the keyboard shortcuts system.
  """
  @callback cleanup() :: :ok | {:error, term()}
end