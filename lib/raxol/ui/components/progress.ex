defmodule Raxol.UI.Components.Progress do
  @moduledoc """
  Provides components for displaying progress, like progress bars and spinners.
  """

  # Delegation to focused modules
  alias Raxol.UI.Components.Progress.{
    Bar,
    Circular,
    Component,
    Indeterminate,
    Spinner
  }

  # Delegate component behaviour
  @doc false
  defdelegate init(props), to: Component
  @doc false
  defdelegate update(msg, state), to: Component
  @doc false
  defdelegate handle_event(event, props, state), to: Component
  @doc false
  defdelegate render(state, props), to: Component
  defdelegate spinner_types(), to: Component

  # Delegate bar operations
  defdelegate bar(value, opts \\ []), to: Bar
  defdelegate bar_with_label(value, label, opts \\ []), to: Bar

  # Delegate spinner operations
  defdelegate spinner(message \\ nil, frame, opts \\ []), to: Spinner

  # Delegate indeterminate operations
  defdelegate indeterminate(frame, opts \\ []), to: Indeterminate

  # Delegate circular operations
  defdelegate circular(value, opts \\ []), to: Circular
end
