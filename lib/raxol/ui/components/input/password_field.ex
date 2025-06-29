defmodule Raxol.UI.Components.Input.PasswordField do
  @moduledoc """
  Password field input component for secure user input.
  This is a thin wrapper around Raxol.UI.Components.Input.TextField, setting secret: true by default.
  All features, options, and behaviour are inherited from TextField.
  """

  alias Raxol.UI.Components.Input.TextField

  @behaviour Raxol.UI.Components.Base.Component

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Ensure secret: true is always set
    TextField.init(Map.put(props, :secret, true))
  end

  @impl Raxol.UI.Components.Base.Component
  def mount(state), do: TextField.mount(state)

  @impl Raxol.UI.Components.Base.Component
  def unmount(state), do: TextField.unmount(state)

  @impl Raxol.UI.Components.Base.Component
  def update(msg, state), do: TextField.update(msg, state)

  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, context, state),
    do: TextField.handle_event(event, context, state)

  @impl Raxol.UI.Components.Base.Component
  def render(state, context), do: TextField.render(state, context)
end
