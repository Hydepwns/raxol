defmodule Raxol.UI.Components.Input.TextArea do
  @moduledoc """
  Text area input component for multi-line user input.
  This is a thin wrapper around Raxol.UI.Components.Input.MultiLineInput for API compatibility.
  All features, options, and behaviour are inherited from MultiLineInput.
  """

  import Raxol.Guards
  alias Raxol.UI.Theming.Theme
  alias Raxol.UI.Components.Input.MultiLineInput

  @behaviour Raxol.UI.Components.Base.Component

  @impl true
  def init(props), do: MultiLineInput.init(props)

  @impl true
  def mount(state), do: MultiLineInput.mount(state)

  @impl true
  def unmount(state), do: MultiLineInput.unmount(state)

  @impl true
  def update(msg, state), do: MultiLineInput.update(msg, state)

  @impl true
  def handle_event(event, context, state),
    do: MultiLineInput.handle_event(event, context, state)

  @impl true
  def render(state, context), do: MultiLineInput.render(state, context)
end
