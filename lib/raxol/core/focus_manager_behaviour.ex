defmodule Raxol.Core.FocusManager.Behaviour do
  @moduledoc """
  Defines the behaviour for focus management services.
  """

  @doc """
  Registers a focusable component.
  """
  @callback register_focusable(
              component_id :: String.t(),
              tab_index :: integer(),
              opts :: Keyword.t()
            ) :: :ok

  @doc """
  Unregisters a focusable component.
  """
  @callback unregister_focusable(component_id :: String.t()) :: :ok

  @doc """
  Sets the initial focus to a specific component.
  """
  @callback set_initial_focus(component_id :: String.t()) :: :ok

  @doc """
  Sets focus to a specific component.
  """
  @callback set_focus(component_id :: String.t()) :: :ok

  @doc """
  Moves focus to the next focusable element.
  """
  @callback focus_next(opts :: Keyword.t()) :: :ok

  @doc """
  Moves focus to the previous focusable element.
  """
  @callback focus_previous(opts :: Keyword.t()) :: :ok

  @doc """
  Gets the ID of the currently focused element.
  """
  @callback get_focused_element() :: String.t() | nil

  @doc """
  Alias for get_focused_element/0.
  """
  @callback get_current_focus() :: String.t() | nil

  @doc """
  Gets the next focusable element after the given one.
  """
  @callback get_next_focusable(current_focus_id :: String.t() | nil) ::
              String.t() | nil

  @doc """
  Gets the previous focusable element before the given one.
  """
  @callback get_previous_focusable(current_focus_id :: String.t() | nil) ::
              String.t() | nil

  @doc """
  Checks if a component has focus.
  """
  @callback has_focus?(component_id :: String.t()) :: boolean()

  @doc """
  Returns to the previously focused element.
  """
  @callback return_to_previous() :: :ok

  @doc """
  Enables a previously disabled focusable component.
  """
  @callback enable_component(component_id :: String.t()) :: :ok

  @doc """
  Disables a focusable component.
  """
  @callback disable_component(component_id :: String.t()) :: :ok

  @doc """
  Registers a handler function to be called when focus changes.
  The handler function should accept two arguments: `old_focus` and `new_focus`.
  """
  @callback register_focus_change_handler(
              handler_fun :: (String.t() | nil, String.t() | nil -> any())
            ) :: :ok

  @doc """
  Unregisters a focus change handler function.
  """
  @callback unregister_focus_change_handler(
              handler_fun :: (String.t() | nil, String.t() | nil -> any())
            ) :: :ok

  @doc """
  Gets the focus history.
  """
  @callback get_focus_history() :: list(String.t() | nil)
end
