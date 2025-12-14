# Raxol Button - React-style Component
import Raxol.HEEx.Components

defmodule ButtonComponent do
  use Phoenix.Component

  attr :label, :string, required: true
  attr :role, :string, default: "primary"
  attr :disabled, :boolean, default: false
  attr :on_click, :string, required: true

  def render(assigns) do
    ~H"""
    <.terminal_button
      phx-click={@on_click}
      role={@role}
      disabled={@disabled}
    >
      <%= @label %>
    </.terminal_button>
    """
  end
end

# Usage in parent component:
# <ButtonComponent.render
#   label="Submit"
#   role="primary"
#   on_click="submit_form"
# />
#
# <ButtonComponent.render
#   label="Cancel"
#   role="secondary"
#   on_click="cancel"
# />
